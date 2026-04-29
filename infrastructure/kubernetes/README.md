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
