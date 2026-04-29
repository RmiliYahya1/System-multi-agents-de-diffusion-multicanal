# ⚠️ SECRETS AUDIT — COMPROMISED CREDENTIALS

> **À SUPPRIMER du repo après rotation. Ne PAS commit en l'état sur un repo public.**
>
> Ce fichier recense TOUS les secrets/credentials trouvés en clair ou en base64
> dans l'historique Git du repo. Ils sont TOUS compromis et doivent être rotés
> AVANT tout déploiement en production.

## Inventaire des secrets compromis

| # | Fichier | Ligne(s) | Type | Valeur en clair | Action |
|---|---|---|---|---|---|
| 1 | `infrastructure/.env` | L2 | Mot de passe PostgreSQL | `DiffUs10n_S3cur3_2026!` | **ROTATE** |
| 2 | `infrastructure/.env` | L5 | Email pgAdmin | `rmiliyahya2@gmail.com` | **ROTATE** |
| 3 | `infrastructure/.env` | L6 | Mot de passe pgAdmin | `admin123` | **ROTATE** |
| 4 | `infrastructure/.env` | L9 | Mot de passe Redis | `R3d1s_D1ffus10n_2026!` | **ROTATE** |
| 5 | `infrastructure/.env` | L15 | Vault root token | `V4ult_R00t_T0k3n_2026!` | **ROTATE** |
| 6 | `infrastructure/.env` | L19 | Kong JWT secret | `Cl3_S3cr3t3_B1ind3e_2026_SUPER_SECRET_KEY!` | **ROTATE** |
| 7 | `infrastructure/.env` | L22 | Clé de chiffrement n8n | `4a7f2e9b1c8d3f6a5e2b9c4d7f1a8e3b6c9d2f5a8b1e4c7d0f3a6b9c2e5f8a1` | **ROTATE** |
| 8 | `infrastructure/kubernetes/base/data/secrets.yaml` | L8 | POSTGRES_PASSWORD (base64) | `DiffUs10n_S3cur3_2026!` | **ROTATE** |
| 9 | `infrastructure/kubernetes/base/data/secrets.yaml` | L9 | REDIS_PASSWORD (base64) | `R3d1s_D1ffus10n_2026!` | **ROTATE** |
| 10 | `infrastructure/kubernetes/base/app/secrets.yaml` | L8 | POSTGRES_PASSWORD (base64) | `DiffUs10n_S3cur3_2026!` | **ROTATE** |
| 11 | `infrastructure/kubernetes/base/app/secrets.yaml` | L9 | REDIS_PASSWORD (base64) | `R3d1s_D1ffus10n_2026!` | **ROTATE** |
| 12 | `infrastructure/kubernetes/base/app/secrets.yaml` | L10 | N8N_ENCRYPTION_KEY (base64) | `4a7f2e9b1c8d3f6a...` | **ROTATE** |
| 13 | `infrastructure/kubernetes/base/gateway/secrets.yaml` | L8 | KONG_JWT_SECRET (base64) | `Cl3_S3cr3t3_B1ind3e_2026_SUPER_SECRET_KEY!` | **ROTATE** |
| 14 | `infrastructure/kubernetes/base/security/secrets.yaml` | L8 | VAULT_TOKEN (base64) | `V4ult_R00t_T0k3n_2026!` | **ROTATE** |
| 15 | `infrastructure/kubernetes/base/gateway/kong-config.yaml` | L27 | Kong JWT secret (plaintext dans ConfigMap) | `Cl3_S3cr3t3_B1ind3e_2026_SUPER_SECRET_KEY!` | **ROTATE** |
| 16 | `infrastructure/kubernetes/base/observability/monitoring.yaml` | L83 | Grafana admin password (plaintext) | `admin` | **ROTATE** |
| 17 | `infrastructure/docker-compose.dev.yml` | L25 | POSTGRES_PASSWORD (default) | `DiffUs10n_S3cur3_2026!` | KEEP (dev only) |
| 18 | `infrastructure/docker-compose.dev.yml` | L74 | PGADMIN_EMAIL (default) | `rmiliyahya2@gmail.com` | KEEP (dev only) |
| 19 | `infrastructure/docker-compose.dev.yml` | L75 | PGADMIN_PASSWORD (default) | `admin123` | KEEP (dev only) |
| 20 | `infrastructure/docker-compose.dev.yml` | L104 | REDIS_PASSWORD (default) | `R3d1s_D1ffus10n_2026!` | KEEP (dev only) |
| 21 | `infrastructure/docker-compose.dev.yml` | L175 | GF_SECURITY_ADMIN_PASSWORD | `admin` | KEEP (dev only) |
| 22 | `infrastructure/docker-compose.dev.yml` | L219 | VAULT_DEV_ROOT_TOKEN_ID | `V4ult_R00t_T0k3n_2026!` | KEEP (dev only) |
| 23 | `infrastructure/scripts/init-vault.sh` | L20 | VAULT_TOKEN (plaintext) | `V4ult_R00t_T0k3n_2026!` | **ROTATE** |
| 24 | `infrastructure/scripts/init-vault.sh` | L41 | Facebook access_token (demo) | `EAAxxxDEMO_ACCESS_TOKEN_FACEBOOK_2026xxx` | **ROTATE** |
| 25 | `infrastructure/scripts/init-vault.sh` | L43 | Facebook client_app_id (demo) | `579564268565837` | **ROTATE** |
| 26 | `infrastructure/scripts/init-vault.sh` | L44 | Facebook client_secret (demo) | `DEMO_CLIENT_SECRET_FB_2026` | **ROTATE** |
| 27 | `infrastructure/scripts/init-vault.sh` | L55 | LinkedIn access_token (demo) | `AQXxxDEMO_ACCESS_TOKEN_LINKEDIN_2026xxx` | **ROTATE** |
| 28 | `infrastructure/scripts/init-vault.sh` | L56 | LinkedIn refresh_token (demo) | `AQXxxDEMO_REFRESH_TOKEN_LINKEDIN_2026xxx` | **ROTATE** |
| 29 | `infrastructure/scripts/init-vault.sh` | L57 | LinkedIn client_app_id (demo) | `86vkxxxxxx` | **ROTATE** |
| 30 | `infrastructure/scripts/init-vault.sh` | L58 | LinkedIn client_secret (demo) | `DEMO_CLIENT_SECRET_LI_2026` | **ROTATE** |
| 31 | `infrastructure/queue-service/node_modules/debug/.coveralls.yml` | L1 | Coveralls repo_token (3rd party) | `SIAeZjKYlHK74rbcFvNHMUzjRiMpflxve` | IGNORE (3rd party dep) |

## Résumé par criticité

| Priorité | Secret | Justification |
|---|---|---|
| 🔴 CRITIQUE | POSTGRES_PASSWORD | Accès total à la base de données |
| 🔴 CRITIQUE | N8N_ENCRYPTION_KEY | Déchiffrement des credentials stockés dans n8n |
| 🔴 CRITIQUE | KONG_JWT_SECRET | Forgery de tokens JWT — accès API complet |
| 🟠 ÉLEVÉ | REDIS_PASSWORD | Accès aux queues et données en cache |
| 🟠 ÉLEVÉ | VAULT_TOKEN | Root token — accès complet à Vault |
| 🟡 MOYEN | PGADMIN_PASSWORD | Interface d'administration DB |
| 🟡 MOYEN | GF_ADMIN_PASSWORD | Interface Grafana |
| 🟡 MOYEN | Facebook/LinkedIn tokens | Tokens de démo — à régénérer |

## Actions requises avant production

1. **Générer de nouveaux secrets** avec `scripts/aws-create-secrets.sh prod`
2. **Ne jamais réutiliser** les valeurs ci-dessus — elles sont dans l'historique Git
3. **Envisager un `git filter-branch`** ou BFG Repo Cleaner pour les purger de l'historique
4. **Supprimer ce fichier** du repo après rotation complète
