# Gestion des Secrets — Architecture et Runbook

## A. Architecture

```text
┌──────────────────────────────────────────────────────────────┐
│                    AWS Secrets Manager                       │
│  ┌─────────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │ diffusion/      │  │ diffusion/   │  │ diffusion/     │  │
│  │ prod/database   │  │ prod/cache   │  │ prod/n8n       │  │
│  │ prod/gateway    │  │ prod/grafana │  │ prod/vault     │  │
│  │ prod/pgadmin    │  │              │  │                │  │
│  └────────┬────────┘  └──────┬───────┘  └───────┬────────┘  │
└───────────┼──────────────────┼──────────────────┼────────────┘
            │                  │                  │
            ▼                  ▼                  ▼
┌──────────────────────────────────────────────────────────────┐
│           External Secrets Operator (ESO)                    │
│           ClusterSecretStore: aws-secrets-manager             │
│           Auth: IRSA (ServiceAccount → IAM Role)             │
└──────────────────────────────────────────────────────────────┘
            │                  │                  │
            ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐
│ ExternalSecret│  │ ExternalSecret│  │ ExternalSecret      │
│ (ns: data)    │  │ (ns: app)    │  │ (ns: gateway/obs/sec)│
└──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘
       ▼                 ▼                     ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐
│ K8s Secret    │  │ K8s Secret    │  │ K8s Secret           │
│ diffusion-   │  │ diffusion-   │  │ kong-secrets /        │
│ secrets      │  │ secrets      │  │ grafana-admin-secret / │
│ (data ns)    │  │ (app ns)     │  │ vault-secrets         │
└──────────────┘  └──────────────┘  └──────────────────────┘
```

## B. Pourquoi External Secrets Operator + AWS Secrets Manager

1. **Zéro secret dans Git** : Les credentials ne sont plus stockés dans le repo.
2. **Rotation automatique** : Mise à jour via AWS SM + `refreshInterval` d'ESO.
3. **Audit trail** : AWS CloudTrail enregistre chaque accès aux secrets.
4. **Isolation par environnement** : Chaque env a ses propres paths (`diffusion/prod/*`, `diffusion/staging/*`).
5. **IRSA** : Authentification sans access keys grâce à IAM Roles for Service Accounts.

## C. Installation d'ESO (une seule fois par cluster)

```bash
# 1. Ajouter le repo Helm
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# 2. Installer le controller ESO + CRDs
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --set installCRDs=true

# 3. Vérifier que le controller est running
kubectl -n external-secrets get pods
```

> **⚠️ IMPORTANT** : Cette installation doit être faite AVANT le premier
> `kubectl apply -k overlays/<env>/`. Le CRD `ExternalSecret` et
> `ClusterSecretStore` doivent exister pour que Kustomize puisse appliquer
> les manifests.

## D. Création des secrets dans AWS Secrets Manager

Utiliser le script fourni :

```bash
# Génère et pousse des secrets NEUFS pour la prod
./scripts/aws-create-secrets.sh prod

# Idem pour staging
./scripts/aws-create-secrets.sh staging
```

Le script :
- Vérifie que `aws` CLI est configuré
- Génère des mots de passe aléatoires via `openssl rand`
- Les pousse dans AWS SM au bon path (`diffusion/<env>/<domain>`)
- Est idempotent (create ou update)
- Ne fait PAS de rollback

## E. Configuration IRSA

### Étapes :

1. **Créer le OIDC Provider** pour le cluster EKS :
   ```bash
   eksctl utils associate-iam-oidc-provider \
     --cluster <CLUSTER_NAME> \
     --approve
   ```

2. **Créer le rôle IAM** avec la politique suivante :
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Action": [
         "secretsmanager:GetSecretValue",
         "secretsmanager:DescribeSecret"
       ],
       "Resource": "arn:aws:secretsmanager:eu-west-3:ACCOUNT_ID:secret:diffusion/*"
     }]
   }
   ```

3. **Configurer la trust policy** du rôle :
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": {
         "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.eu-west-3.amazonaws.com/id/OIDC_ID"
       },
       "Action": "sts:AssumeRoleWithWebIdentity",
       "Condition": {
         "StringEquals": {
           "oidc.eks.eu-west-3.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:external-secrets:external-secrets"
         }
       }
     }]
   }
   ```

4. **Mettre à jour l'ARN** dans l'overlay correspondant :
   `overlays/<env>/patches/external-secrets-env.yaml`

## F. Comment ajouter un nouveau secret

1. Créer le secret dans AWS SM : `aws secretsmanager create-secret --name diffusion/<env>/<domain> --secret-string '{"KEY":"value"}'`
2. Créer/mettre à jour l'`ExternalSecret` dans `base/<layer>/external-secret-*.yaml`
3. Ajouter le fichier au `kustomization.yaml` de la couche
4. Mettre à jour les patches de chaque overlay pour remplacer `REPLACE_ENV`
5. Commit + déployer

## G. Comment roter un secret

### Rotation via AWS SM (recommandé)

1. Mettre à jour la valeur dans AWS SM :
   ```bash
   aws secretsmanager update-secret \
     --secret-id diffusion/prod/database \
     --secret-string '{"POSTGRES_PASSWORD":"NouveauMotDePasse"}'
   ```

2. Attendre le `refreshInterval` (1h par défaut), ou forcer le sync :
   ```bash
   kubectl annotate externalsecret external-secret-data \
     -n prod-data \
     force-sync=$(date +%s) --overwrite
   ```

3. Redémarrer les pods qui consomment le secret :
   ```bash
   kubectl rollout restart deployment -n prod-app
   ```

## H. Le cas dev local

Sur Docker Desktop / Minikube, il n'y a pas d'AWS Secrets Manager.
L'overlay `dev` :
- **Supprime** les ExternalSecret et ClusterSecretStore via `patches/disable-external-secrets.yaml`
- **Injecte** des Secret K8s natifs via `local-secrets.yaml` avec des credentials de développement uniquement

> Les credentials de dev sont isolées et ne sont JAMAIS utilisées en prod.

## I. Secrets compromis à roter

Voir `docs/security/SECRETS_AUDIT.md` pour la liste complète.

**Action immédiate** : Exécuter `./scripts/aws-create-secrets.sh prod` pour
générer des credentials neufs AVANT le premier déploiement en production.
