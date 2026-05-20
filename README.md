# Projet de Diffusion Multicanal

## Développement local

Pour exécuter le projet en développement local, utilisez le fichier Docker Compose dédié :
`docker compose -f infrastructure/docker-compose.dev.yml up -d`

## Déploiement production

Voir `infrastructure/kubernetes/`

## Configuration des Secrets

**IMPORTANT** : La variable d'environnement \VAULT_ROOT_TOKEN\ (utilis�e par CredentialsService) doit �tre configur�e dans les secrets Kubernetes (par exemple dans \diffusion-secrets\ ou \ault-secrets\). Voir \local-secrets.yaml\ pour l'environnement de dev.
