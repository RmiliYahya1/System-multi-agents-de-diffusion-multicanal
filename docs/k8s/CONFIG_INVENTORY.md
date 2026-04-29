# Inventaire des variables de configuration Kubernetes

> Généré automatiquement à l'étape 5/15. Ce document recense toutes les
> variables d'environnement extraites des Deployments/StatefulSets vers
> des ConfigMaps dédiées.

## Résumé

| Catégorie | Nombre de variables |
|---|---|
| STATIQUE_COMMUNE (→ ConfigMap base) | 32 |
| VARIABLE_PAR_ENV (→ ConfigMap base + overlay merge) | 5 |
| REFERENCE_SECRET (→ secretKeyRef, inchangé) | 10 |
| **Total** | **47** |

## Inventaire détaillé

### base/data/postgres.yaml (StatefulSet)

| Variable | Valeur actuelle | Catégorie | Cible ConfigMap |
|---|---|---|---|
| POSTGRES_DB | `diffusion_db` | STATIQUE_COMMUNE | postgres-config |
| POSTGRES_USER | `diffusion_admin` | STATIQUE_COMMUNE | postgres-config |
| POSTGRES_PASSWORD | secretKeyRef | REFERENCE_SECRET | — |
| TZ | `Africa/Casablanca` | STATIQUE_COMMUNE | postgres-config |
| PGTZ | `Africa/Casablanca` | STATIQUE_COMMUNE | postgres-config |
| DATA_SOURCE_URI | `localhost:5432/diffusion_db?sslmode=disable` | STATIQUE_COMMUNE | (inline sidecar) |
| DATA_SOURCE_USER | `diffusion_admin` | STATIQUE_COMMUNE | (inline sidecar) |
| DATA_SOURCE_PASS | secretKeyRef | REFERENCE_SECRET | — |

### base/data/redis.yaml (StatefulSet)

| Variable | Valeur actuelle | Catégorie | Cible ConfigMap |
|---|---|---|---|
| --maxmemory (CLI) | `1gb` | STATIQUE_COMMUNE | redis-config |
| --maxmemory-policy (CLI) | `allkeys-lru` | STATIQUE_COMMUNE | redis-config |
| --appendonly (CLI) | `yes` | STATIQUE_COMMUNE | redis-config |
| REDIS_PASSWORD | secretKeyRef | REFERENCE_SECRET | — |
| REDIS_ADDR (exporter) | `redis://localhost:6379` | STATIQUE_COMMUNE | (inline sidecar) |

### base/app/n8n-main.yaml (Deployment)

| Variable | Valeur actuelle | Catégorie | Cible ConfigMap |
|---|---|---|---|
| N8N_HOST | `0.0.0.0` | STATIQUE_COMMUNE | n8n-config |
| N8N_PORT | `5678` | STATIQUE_COMMUNE | n8n-config |
| WEBHOOK_URL | `http://n8n-main:5678/` | STATIQUE_COMMUNE | (inline, spécifique main) |
| GENERIC_TIMEZONE | `Africa/Casablanca` | STATIQUE_COMMUNE | n8n-config |
| EXECUTIONS_MODE | `queue` | STATIQUE_COMMUNE | n8n-config |
| QUEUE_HEALTH_CHECK_ACTIVE | `true` | STATIQUE_COMMUNE | n8n-config |
| QUEUE_BULL_REDIS_HOST | `redis` | STATIQUE_COMMUNE | n8n-config |
| QUEUE_BULL_REDIS_PORT | `6379` | STATIQUE_COMMUNE | n8n-config |
| DB_TYPE | `postgresdb` | STATIQUE_COMMUNE | n8n-config |
| DB_POSTGRESDB_HOST | `postgres` | STATIQUE_COMMUNE | n8n-config |
| DB_POSTGRESDB_PORT | `5432` | STATIQUE_COMMUNE | n8n-config |
| DB_POSTGRESDB_DATABASE | `diffusion_db` | STATIQUE_COMMUNE | n8n-config |
| DB_POSTGRESDB_USER | `diffusion_admin` | STATIQUE_COMMUNE | n8n-config |
| N8N_RUNNERS_ENABLED | `true` | STATIQUE_COMMUNE | n8n-config |
| N8N_CONCURRENCY_PRODUCTION_LIMIT | `20` | VARIABLE_PAR_ENV | n8n-config |
| N8N_PAYLOAD_SIZE_MAX | `64` | STATIQUE_COMMUNE | n8n-config |
| EXECUTIONS_DATA_PRUNE | `true` | STATIQUE_COMMUNE | n8n-config |
| EXECUTIONS_DATA_MAX_AGE | `168` | VARIABLE_PAR_ENV | n8n-config |
| QUEUE_BULL_REDIS_PASSWORD | secretKeyRef | REFERENCE_SECRET | — |
| DB_POSTGRESDB_PASSWORD | secretKeyRef | REFERENCE_SECRET | — |
| N8N_ENCRYPTION_KEY | secretKeyRef | REFERENCE_SECRET | — |

### base/app/n8n-worker.yaml (Deployment)

| Variable | Valeur actuelle | Catégorie | Cible ConfigMap |
|---|---|---|---|
| (mêmes variables que n8n-main sauf WEBHOOK_URL, N8N_HOST, N8N_PORT) | — | STATIQUE_COMMUNE | n8n-config |
| N8N_CONCURRENCY_PRODUCTION_LIMIT | `10` | VARIABLE_PAR_ENV | (inline, worker-spécifique) |

### base/app/queue-service.yaml (Deployment)

| Variable | Valeur actuelle | Catégorie | Cible ConfigMap |
|---|---|---|---|
| REDIS_HOST | `redis` | STATIQUE_COMMUNE | queue-service-config |
| REDIS_PORT | `6379` | STATIQUE_COMMUNE | queue-service-config |
| N8N_WEBHOOK_BASE_URL | `http://n8n-main:5678` | STATIQUE_COMMUNE | queue-service-config |
| QUEUE_SERVICE_PORT | `3002` | STATIQUE_COMMUNE | queue-service-config |
| NODE_ENV | (absent) | VARIABLE_PAR_ENV | queue-service-config |
| LOG_LEVEL | (absent) | VARIABLE_PAR_ENV | queue-service-config |
| REDIS_PASSWORD | secretKeyRef | REFERENCE_SECRET | — |

### base/gateway/kong.yaml (Deployment)

| Variable | Valeur actuelle | Catégorie | Cible ConfigMap |
|---|---|---|---|
| KONG_DATABASE | `off` | STATIQUE_COMMUNE | kong-runtime-config |
| KONG_DECLARATIVE_CONFIG | `/usr/local/kong/declarative/kong.yml` | STATIQUE_COMMUNE | kong-runtime-config |
| KONG_PROXY_ACCESS_LOG | `/dev/stdout` | STATIQUE_COMMUNE | kong-runtime-config |
| KONG_ADMIN_ACCESS_LOG | `/dev/stdout` | STATIQUE_COMMUNE | kong-runtime-config |
| KONG_PROXY_ERROR_LOG | `/dev/stderr` | STATIQUE_COMMUNE | kong-runtime-config |
| KONG_ADMIN_ERROR_LOG | `/dev/stderr` | STATIQUE_COMMUNE | kong-runtime-config |
| KONG_ADMIN_LISTEN | `0.0.0.0:8001` | STATIQUE_COMMUNE | kong-runtime-config |

### base/observability/monitoring.yaml (Grafana Deployment)

| Variable | Valeur actuelle | Catégorie | Cible ConfigMap |
|---|---|---|---|
| GF_SECURITY_ADMIN_USER | `admin` | STATIQUE_COMMUNE | (inline) |
| GF_SECURITY_ADMIN_PASSWORD | secretKeyRef | REFERENCE_SECRET | — |
| GF_USERS_ALLOW_SIGN_UP | `false` | STATIQUE_COMMUNE | (inline) |

### base/security/vault.yaml (Deployment)

| Variable | Valeur actuelle | Catégorie | Cible ConfigMap |
|---|---|---|---|
| VAULT_ADDR | `http://0.0.0.0:8200` | STATIQUE_COMMUNE | (inline) |
| VAULT_API_ADDR | `http://vault:8200` | STATIQUE_COMMUNE | (inline) |
| VAULT_TOKEN | secretKeyRef | REFERENCE_SECRET | — |
