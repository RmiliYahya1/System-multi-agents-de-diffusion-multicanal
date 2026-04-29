# Kubernetes Hardening Standards — Diffusion Platform

> **Scope** : tous les workloads dans `infrastructure/kubernetes/`.
> **Étape** : 6/15 — Hardening complet des Deployments et StatefulSets.

---

## A. Convention des labels (`app.kubernetes.io/*`)

Chaque workload (StatefulSet, Deployment, CronJob) DOIT porter les six labels suivants
sur `metadata` ET sur `spec.template.metadata` :

| Label | Valeurs possibles |
|---|---|
| `app.kubernetes.io/name` | Nom du workload (ex. `postgres`, `n8n-main`, `n8n-worker`) |
| `app.kubernetes.io/instance` | Identique à `name` pour nos déploiements single-instance |
| `app.kubernetes.io/version` | Version sémantique de l'image (ex. `"16.6"`, `"1.78.1"`) |
| `app.kubernetes.io/component` | Voir tableau ci-dessous |
| `app.kubernetes.io/part-of` | `diffusion-platform` (constant) |
| `app.kubernetes.io/managed-by` | `kustomize` (constant) |

### Valeurs de `component` par workload

| Workload | component |
|---|---|
| postgres | `database` |
| redis | `cache` |
| n8n-main | `workflow-engine` |
| n8n-worker | `worker` |
| queue-service | `microservice` |
| kong | `gateway` |
| vault | `security` |
| prometheus | `monitoring` |
| grafana | `dashboard` |
| postgres-backup, redis-backup | `backup` |

Le label existant `app: <name>` est **conservé** sur les pods pour rétrocompatibilité
avec les `selector` des Services.

---

## B. Convention de version pinning

- **Interdit** : `:latest` en staging et prod. Toléré uniquement en dev (images locales).
- **Format requis** : `X.Y.Z` ou `X.Y.Z-variant` (ex. `16.6-alpine`, `1.78.1`).
- **Digest SHA256** : recommandé en prod pour les images critiques (hors périmètre étape 6).
- **Mécanisme overlay** : les versions sont surchargées via le champ `images:` de
  Kustomize dans chaque overlay — ne pas hardcoder dans les overlays, uniquement
  dans le `kustomization.yaml`.

### Procédure de mise à jour d'image

1. Modifier `newTag` dans `overlays/<env>/kustomization.yaml` (section `images:`).
2. Ouvrir une PR — la CI lance `kubeconform` + `kube-score`.
3. Valider en staging (appliquer, vérifier les probes).
4. Merger en prod.

---

## C. SecurityContext — niveau Pod (standard)

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: <voir tableau UID>
  runAsGroup: <voir tableau UID>
  fsGroup: <voir tableau UID>
  fsGroupChangePolicy: OnRootMismatch   # seulement pour les workloads avec PVC
  seccompProfile:
    type: RuntimeDefault
```

### Tableau des UID par workload

| Workload | runAsUser | runAsGroup | fsGroup | Source |
|---|---|---|---|---|
| postgres | 70 | 70 | 70 | UID postgres dans alpine |
| postgres-exporter | 65534 | — | — | nobody |
| redis | 999 | 999 | 999 | UID redis dans alpine |
| redis-exporter | 65534 | — | — | nobody |
| n8n-main | 1000 | 1000 | 1000 | UID node dans alpine |
| n8n-worker | 1000 | 1000 | 1000 | UID node dans alpine |
| queue-service | 1000 | 1000 | 1000 | USER node dans Dockerfile |
| kong | 100 | 1000 | 1000 | UID kong dans image officielle |
| vault | 100 | 1000 | 1000 | UID vault dans image officielle |
| prometheus | 65534 | 65534 | 65534 | nobody (image officielle) |
| grafana | 472 | 472 | 472 | UID grafana dans image officielle |
| postgres-backup (CronJob) | 70 | 70 | 70 | idem postgres |
| redis-backup (CronJob) | 999 | 999 | 999 | idem redis |

---

## D. SecurityContext — niveau Container (standard)

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]
```

Quand `readOnlyRootFilesystem: true`, chaque chemin d'écriture nécessaire doit être
couvert par un volume `emptyDir`. Voir tableau E.

---

## E. Volumes emptyDir requis par workload (readOnlyRootFilesystem)

| Workload | Chemins writable | Volume emptyDir |
|---|---|---|
| postgres | `/tmp`, `/var/run/postgresql` | `tmp`, `postgres-run` |
| redis | `/tmp` | `tmp` |
| n8n-main | `/home/node/.n8n`, `/tmp` | `n8n-home`, `tmp` |
| n8n-worker | `/home/node/.n8n`, `/tmp` | `n8n-home`, `tmp` |
| queue-service | `/tmp` | `tmp` |
| kong | `/tmp`, `/usr/local/kong/logs` | `tmp`, `kong-logs` |
| kong (initContainer) | — (readOnly) | — |
| prometheus | `/tmp` | `tmp` |

> **À valider en staging** : les chemins exacts pour `n8n` (`/home/node/.n8n`
> est utilisé pour les credentials et sessions). Si n8n écrit ailleurs, ajouter
> les emptyDir correspondants.

---

## F. Probes

| Type | Usage | Workloads concernés |
|---|---|---|
| `startupProbe` | Temps de boot initial (migrations DB, init) | Tous sauf CronJobs |
| `livenessProbe` | Détecte les deadlocks / blocages | Tous sauf CronJobs |
| `readinessProbe` | Contrôle le trafic entrant | Services HTTP |

### Paramètres recommandés par type de service

| Service | startupProbe `failureThreshold × periodSeconds` | Justification |
|---|---|---|
| postgres | 30 × 10 s = 5 min | Init DB peut prendre du temps |
| redis | 30 × 5 s = 2.5 min | Démarrage rapide |
| n8n-main | 60 × 10 s = 10 min | Migrations Postgres au premier boot |
| n8n-worker | 30 × 10 s = 5 min | Démarrage via pgrep |
| queue-service | 30 × 5 s = 2.5 min | App Node.js légère |
| kong | 30 × 5 s = 2.5 min | Init Kong rapide |
| vault | 30 × 5 s = 2.5 min | Init Vault |
| prometheus | 30 × 10 s = 5 min | Chargement des règles |
| grafana | 30 × 5 s = 2.5 min | Init Grafana |

> **Limitation connue** : n8n-worker utilise `pgrep -f 'n8n'` car l'image n8n
> ne contient pas `redis-cli`. La readinessProbe ne peut donc pas vérifier la
> connectivité Redis directement. À valider en staging : envisager un sidecar
> redis-cli ou un script de healthcheck custom.

---

## G. Resources recommandées par workload

| Workload | CPU request | CPU limit | Mem request | Mem limit |
|---|---|---|---|---|
| postgres | 250m | 2 | 512Mi | 2Gi |
| redis | 100m | — | 512Mi | 1.5Gi |
| n8n-main | 500m | 2 | 512Mi | 2Gi |
| n8n-worker | 250m | 1500m | 256Mi | 1.5Gi |
| queue-service | 100m | 500m | 128Mi | 512Mi |
| kong | 100m | 500m | 256Mi | 1Gi |
| vault | 100m | 500m | 64Mi | 256Mi |
| prometheus | 250m | 1 | 1Gi | 2Gi |
| grafana | 100m | 500m | 128Mi | 512Mi |
| postgres-backup | 100m | — | 128Mi | 512Mi |
| redis-backup | 100m | — | 128Mi | 512Mi |

---

## H. terminationGracePeriodSeconds

| Workload | Valeur | Justification |
|---|---|---|
| postgres | 60 s | Flush WAL + checkpoint propre |
| redis | 30 s | Flush AOF + BGSAVE |
| n8n-main | 60 s | Drain des webhooks en cours |
| n8n-worker | 300 s | Un job peut durer jusqu'à ~30 s (ex : publication LinkedIn) |
| queue-service | 60 s | Drain de la file Bull |
| kong | 30 s | Proxy sans état |
| vault | 30 s | Pas d'état volatile |
| prometheus | 30 s | Pas de drain nécessaire |
| grafana | 30 s | Pas de drain nécessaire |

---

## I. Annotations Prometheus (scraping)

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "<port>"
  prometheus.io/path: "/metrics"   # optionnel si /metrics
```

| Workload | Port | Path |
|---|---|---|
| postgres (via exporter) | 9187 | /metrics |
| redis (via exporter) | 9121 | /metrics |
| n8n-main | 5678 | /metrics |
| queue-service | 3002 | /metrics |
| grafana | 3000 | /metrics |

> n8n-worker : pas de port HTTP → pas d'annotation Prometheus.

---

## J. Stratégie de déploiement

| Workload | Strategy | maxSurge | maxUnavailable | Justification |
|---|---|---|---|---|
| n8n-main | RollingUpdate | 1 | 0 | Zéro downtime, 1 seul replica base |
| n8n-worker | RollingUpdate | 2 | 1 | Stateless, remplaçable rapidement |
| queue-service | RollingUpdate | 1 | 0 | Service critique |
| kong | RollingUpdate | 1 | 0 | Front — zéro downtime impératif |
| vault | — (pas de rolling) | — | — | Singleton, géré manuellement |
| prometheus | RollingUpdate | 1 | 0 | Singleton |
| grafana | RollingUpdate | 1 | 0 | Singleton |

StatefulSets :
- **postgres** : `updateStrategy: OnDelete` (conservateur — mise à jour manuelle).
- **redis** : `updateStrategy: RollingUpdate`.

---

## K. Exceptions au standard

| Workload | Règle non appliquée | Raison | Statut |
|---|---|---|---|
| Vault | `readOnlyRootFilesystem: false` | Vault écrit dans `/vault/data` (stockage fichier) | Acceptée — PVC dédié |
| Vault | `capabilities: add: [IPC_LOCK]` | Vault utilise mlock() pour empêcher le swap des secrets | Acceptée — requis par Vault |
| Grafana | `readOnlyRootFilesystem: false` | Grafana écrit plugins, sessions et SQLite dans `/var/lib/grafana` | Acceptée — PVC dédié |

---

## L. Workloads dont les emptyDir sont à valider en staging

- **n8n-main / n8n-worker** : `/home/node/.n8n` — à vérifier si d'autres chemins
  sont écrits au runtime (logs, temp files dans `/tmp/n8n-*`).
- **queue-service** : `/tmp` — à confirmer qu'aucun module npm n'écrit hors de `/tmp`.
- **kong** : `/usr/local/kong/logs` — à confirmer que les logs vont bien ici
  et non dans un autre chemin selon la version.
