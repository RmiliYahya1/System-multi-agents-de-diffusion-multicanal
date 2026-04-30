# Déploiement Kubernetes via Kustomize

Ce dossier contient la configuration de déploiement pour le cluster Kubernetes cible (AWS EKS). Le déploiement est géré via **Kustomize** pour permettre une configuration DRY entre les environnements.

## Structure du dossier

- `base/` : Contient les manifests Kubernetes "vanilla" qui constituent le socle de l'application (valeurs par défaut).
- `overlays/` : Contient les déclinaisons par environnement.
  - `dev/` : Développement local (ex: Docker Desktop) avec limitations de ressources et de replicas.
  - `staging/` : Environnement de pré-production.
  - `prod/` : Environnement de production avec Auto-Scaling et volumes persistants adaptés.

## Comment déployer un environnement

Appliquer les manifests via Kustomize en utilisant l'option `-k` de `kubectl` :

```bash
# Pour le développement local
kubectl apply -k infrastructure/kubernetes/overlays/dev/

# Pour le staging
kubectl apply -k infrastructure/kubernetes/overlays/staging/

# Pour la production
kubectl apply -k infrastructure/kubernetes/overlays/prod/
```

## Vérifier le rendu Kustomize sans l'appliquer (Dry-run)

Il est recommandé de prévisualiser les manifests générés par Kustomize avec la commande suivante :

```bash
kubectl kustomize infrastructure/kubernetes/overlays/<environnement>/
```

## Résumé des Patches par Environnement

| Patch ciblé | dev | staging | prod |
|---|---|---|---|
| **Ingress Host** | `localhost` | `staging.diffusion.iaweb.dev` | `diffusion.iaweb.dev` |
| **Replicas & HPA** | Désactivé, 1 replica par composant | Standard (base) | n8n-main: 2, queue: 2, worker: 3-15 (HPA) |
| **Resources (RAM/CPU)**| Réduites de 50% | Standard (base) | Standard (base) |
| **Storage Class (PVC)** | Standard (base) | `gp3` (AWS) | `gp3` (AWS) + Tailles augmentées |
| **NodePort Services** | Inclus (pour accès direct local) | Exclus | Exclus |
| **Image Tag (queue)** | `latest` | `staging` | `v1.0.0` |

## Architecture multi-namespace

L'application est découpée en 5 couches fonctionnelles réparties dans des namespaces distincts. Kustomize préfixe automatiquement ces namespaces par l'environnement cible (ex: `prod-data`, `dev-app`).

| Couche | Rôle | Composants principaux |
|---|---|---|
| `data` | Persistance et stockage | PostgreSQL, Redis, Volumes |
| `app` | Cœur logique et processing | n8n, Queue Service |
| `gateway` | Routage et point d'entrée | Ingress, Kong |
| `observability` | Monitoring et alertes | Prometheus, Grafana, Exporters |
| `security` | Gestion des secrets | Vault |

### Dépendances inter-namespaces

La résolution DNS entre les composants se fait via des Services `ExternalName` pour conserver un couplage faible entre les couches.

```text
  [Gateway] ---> [App] ---> [Data]
     |             |          |
     |             v          |
     |        [Security]      |
     |                        |
     +---- [Observability] ---+
```

Les secrets sont gérés par **External Secrets Operator** (AWS Secrets Manager). Voir [docs/security/SECRETS_MANAGEMENT.md](../../docs/security/SECRETS_MANAGEMENT.md).

## Gestion de la configuration

### ConfigMap vs Secret

- **ConfigMap** : données non-sensibles (URLs, ports, modes, noms de bases, fuseaux horaires). Visibles en clair dans `kubectl describe`.
- **Secret** : données sensibles (mots de passe, clés d'API, tokens). Gérés via External Secrets Operator depuis AWS Secrets Manager. Voir [docs/security/SECRETS_MANAGEMENT.md](../../docs/security/SECRETS_MANAGEMENT.md).

### Pattern `envFrom`

Les ConfigMaps consommées en variables d'environnement utilisent `envFrom` plutôt que `env` individuel :

```yaml
envFrom:
  - configMapRef:
      name: n8n-config
env:
  - name: DB_POSTGRESDB_PASSWORD   # secret uniquement
    valueFrom:
      secretKeyRef:
        name: diffusion-secrets
        key: POSTGRES_PASSWORD
```

### Surcharger une variable dans un overlay

Pour modifier une valeur de ConfigMap dans un environnement spécifique, utilisez `configMapGenerator` avec `behavior: merge` dans l'overlay :

```yaml
# overlays/dev/kustomization.yaml
configMapGenerator:
  - name: n8n-config
    behavior: merge
    namespace: app
    literals:
      - LOG_LEVEL=debug
      - EXECUTIONS_DATA_MAX_AGE=24

generatorOptions:
  disableNameSuffixHash: true
```

### Hot-reload

Le hot-reload des ConfigMaps n'est **pas géré automatiquement** — les Pods doivent être redémarrés après un changement de ConfigMap. Si ce besoin devient critique, envisager **Stakater Reloader** (étape future).

### Tableau récapitulatif — qui consomme quoi

| ConfigMap | Namespace | Consommée par | Mode |
|---|---|---|---|
| `postgres-config` | `data` | postgres StatefulSet | `envFrom` |
| `redis-config` | `data` | redis StatefulSet | `envFrom` |
| `n8n-config` | `app` | n8n-main, n8n-worker | `envFrom` |
| `queue-service-config` | `app` | queue-service | `envFrom` |
| `app-common-config` | `app` | *(réserve future)* | — |
| `kong-runtime-config` | `gateway` | kong | `envFrom` |
| `kong-declarative-config` | `gateway` | kong initContainer → volume | fichier |
| `prometheus-config` | `observability` | prometheus | volume `/etc/prometheus` |
| `prometheus-rules` | `observability` | prometheus | volume `/etc/prometheus/rules` |
| `grafana-datasources` | `observability` | grafana | volume `/etc/grafana/provisioning/datasources` |
| `grafana-dashboards-config` | `observability` | grafana | volume `/etc/grafana/provisioning/dashboards` |
| `vault-config` | `security` | vault | volume `/vault/config` |

Inventaire complet des variables : [docs/k8s/CONFIG_INVENTORY.md](../../docs/k8s/CONFIG_INVENTORY.md)

---

## Services et exposition

Conventions complètes : [docs/k8s/SERVICES_CONVENTIONS.md](../../docs/k8s/SERVICES_CONVENTIONS.md)

### Tableau de tous les Services (base)

| Nom | Namespace | Type | Port (Service) | targetPort | appProtocol | Exposé via |
|---|---|---|---|---|---|---|
| `postgres` | `data` | Headless | 5432 (postgres), 9187 (metrics) | postgres, metrics | postgresql, http | Interne |
| `redis` | `data` | Headless | 6379 (redis), 9121 (metrics) | redis, metrics | redis, http | Interne |
| `n8n-main` | `app` | ClusterIP | 5678 (http) | http | http | Ingress → `/` |
| `queue-service` | `app` | ClusterIP | 3002 (http) | http | http | Interne |
| `kong-proxy` | `gateway` | ClusterIP | 80 (proxy) | proxy (→8000) | http | Ingress → `/webhook/` |
| `kong-admin` | `gateway` | ClusterIP | 8001 (admin) | admin | http | **Jamais exposé** |
| `n8n-main` | `gateway` | ExternalName | 5678 (http) | — | http | Alias Ingress |
| `vault` | `security` | ClusterIP | 8200 (http) | http | http | Interne |
| `prometheus` | `observability` | ClusterIP | 9090 (http) | http | http | Interne |
| `grafana` | `observability` | ClusterIP | 3000 (http) | http | http | Interne |
| `postgres-exporter` | `observability` | ExternalName | 9187 (metrics) | — | http | Alias scraping |
| `redis-exporter` | `observability` | ExternalName | 9121 (metrics) | — | http | Alias scraping |
| `n8n-main` | `observability` | ExternalName | 5678 (http) | — | http | Alias scraping |
| `queue-service` | `observability` | ExternalName | 3002 (http) | — | http | Alias scraping |
| `postgres` | `app` | ExternalName | 5432 (postgres) | — | postgresql | Alias DB |
| `redis` | `app` | ExternalName | 6379 (redis) | — | redis | Alias cache |

### NodePorts dev uniquement (overlay dev)

| Nom | Namespace | nodePort | Cible |
|---|---|---|---|
| `n8n-main-nodeport` | `app` | 30678 | n8n UI |
| `grafana-nodeport` | `observability` | 30300 | Grafana |
| `queue-service-nodeport` | `app` | 30302 | queue-service |
| `vault-nodeport` | `security` | 30820 | Vault |
| `prometheus-nodeport` | `observability` | 30909 | Prometheus |
| `kong-proxy-nodeport` | `gateway` | 30800 | Kong webhooks |

> **Note** : `kong-admin` n'a **jamais** de NodePort, même en dev.
> Accès admin : `kubectl port-forward svc/dev-kong-admin 8001:8001 -n dev-gateway`

### Exposition publique

```
Internet → Ingress ALB (étape 8)
             ├── /webhook/* → kong-proxy:80 → Kong → n8n-main:5678 (JWT)
             └── /*         → n8n-main:5678 (direct)
```

Tous les autres Services sont **exclusivement ClusterIP/Headless** — aucun accès depuis l'extérieur sans passer par l'Ingress.
