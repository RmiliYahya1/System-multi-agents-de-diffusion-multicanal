# Déploiement sur VM Linux (Ubuntu 22.04)

Ce guide décrit le processus de déploiement de l'infrastructure sur une machine virtuelle Linux via Docker Compose.

## Prérequis

- Docker Engine 24+
- Docker Compose v2
- Git

## Installation rapide

Suivez ces étapes pour démarrer l'infrastructure :

```bash
# Cloner le dépôt et se rendre dans le dossier
git clone <url-du-repo>
cd System-multi-agents-de-diffusion-multicanal

# Préparer le fichier d'environnement
cp infrastructure/.env.vm infrastructure/.env

# Éditer le fichier .env pour y configurer vos mots de passe
nano infrastructure/.env

# Démarrer les services
docker compose -f infrastructure/docker-compose.vm.yml up -d
```

## Ports exposés

| Port | Service | URL d'accès / Description |
|---|---|---|
| `80` | Nginx (Reverse Proxy) | `http://localhost/` (n8n)<br>`http://localhost/webhook/` (Kong)<br>`http://localhost/grafana/` (Grafana)<br>`http://localhost/prometheus/` (Prometheus) |
| `8200` | Vault | `http://localhost:8200` |
| `5050` | pgAdmin | `http://localhost:5050` |

> Tous les autres ports (5432, 6379, 8000, 5678, 9090, 3000, 3002) restent strictement internes au réseau `diffusion-network`.

## Premier démarrage de Vault

```bash
# 1. Initialiser Vault (une seule fois, à la toute première installation)
docker exec diffusion-vault vault operator init -key-shares=1 -key-threshold=1
# → Noter la "Unseal Key" et le "Initial Root Token" dans un endroit sûr

# 2. Unsealer Vault (à faire après chaque redémarrage du conteneur)
docker exec diffusion-vault vault operator unseal <UNSEAL_KEY>

# 3. Pousser les credentials (une seule fois après init)
docker exec diffusion-vault sh /vault/scripts/init-vault.sh
```

*(L'étape 1 et 3 ne se font qu'une seule fois. L'étape 2 est nécessaire à chaque redémarrage du conteneur Vault)*

## Smoke test

Exécutez ces requêtes (après le démarrage) pour vérifier que chaque composant critique répond correctement :

```bash
# 1. Vérifier que n8n répond à la racine
curl -I http://localhost/

# 2. Vérifier que Kong répond sur la route /webhook/
curl -I http://localhost/webhook/

# 3. Vérifier que Grafana répond
curl -I http://localhost/grafana/

# 4. Vérifier l'état de Vault
curl -s http://localhost:8200/v1/sys/health | grep '"initialized"'

# 5. Vérifier que le reverse proxy Nginx est actif
curl -I http://localhost/
```


## Import des workflows n8n

1. Ouvrir n8n à `http://<IP_VM>/` après le démarrage
2. Importer chaque fichier JSON depuis `workflows/` via **Settings → Import Workflow**
3. Activer chaque workflow importé (toggle "Active")

L'ordre d'import recommandé : **services** (LogService, JobService, ChannelConfigService, CredentialsService) → **agents** (IngestionAgent, AdaptationAgent, PublicationAgent) → **workers** (IngestionWorker, AdaptationWorker, PublicationWorker) → **orchestrateur** (OrchestratorAgent)

## Arrêt / Reset

- **Arrêter les services** (conserve les données) :
  ```bash
  docker compose -f infrastructure/docker-compose.vm.yml down
  ```

- **Arrêter et réinitialiser** (⚠️ supprime toutes les données et volumes) :
  ```bash
  docker compose -f infrastructure/docker-compose.vm.yml down -v
  ```
