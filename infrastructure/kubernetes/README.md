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

_Note: Tous les environnements partagent les mêmes Secrets et ConfigMaps définis dans la `base/`._
