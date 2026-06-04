# Audit de couplage AWS avant migration OVHcloud MKS

## Synthèse exécutive

- **Fichiers AWS-spécifiques** : 30 fichiers identifiés avec 153 points de couplage.
- **Top 3 des fichiers les plus couplés** :
  1. `docs/security/SECRETS_MANAGEMENT.md`
  2. `infrastructure/kubernetes/overlays/dev/patches/disable-external-secrets.yaml`
  3. `infrastructure/kubernetes/overlays/prod/patches/external-secrets-env.yaml`
- **Top 3 des risques de migration** :
  1. Gestion des secrets : Remplacement d'AWS Secrets Manager par Vault.
  2. Stockage : Migration des PVC gp3 vers csi-cinder-high-speed.
  3. Réseau et Ingress : Remplacement de l'ALB AWS par un Ingress Controller managé Nginx.
- **Estimation de l'effort par couche** :
  - *Compute / Kubernetes* : Faible (modification de Kustomize, image registry).
  - *Storage / Network* : Moyen (modification des StorageClasses, Ingress).
  - *Security / Secrets* : Élevé (refonte du workflow External Secrets + Vault).

## Étape 2 — Grep exhaustif (passe 1)

### infrastructure/kubernetes/base/app/external-secret-app.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 1 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 9 | `name: aws-secrets-manager` | Registry |
| 10 | `kind: ClusterSecretStore` | Registry |

### infrastructure/kubernetes/base/app/queue-service.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 50 | `image: ACCOUNT_ID.dkr.ecr.eu-west-3.amazonaws.com/diffusion-queue-service:v1.0.0` | Registry |

### infrastructure/kubernetes/base/data/backups-cronjobs.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 129 | `echo "Redis save triggered. Note: Real backups of the appendonly.aof require AWS S3 or a separate script to copy the RDB."` | Misc |

### infrastructure/kubernetes/base/data/external-secret-data.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 1 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 9 | `name: aws-secrets-manager` | Registry |
| 10 | `kind: ClusterSecretStore` | Registry |

### infrastructure/kubernetes/base/data/external-secret-pgadmin.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 1 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 9 | `name: aws-secrets-manager` | Registry |
| 10 | `kind: ClusterSecretStore` | Registry |

### infrastructure/kubernetes/base/external-secrets/cluster-secret-store.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 1 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 2 | `kind: ClusterSecretStore` | Registry |
| 4 | `name: aws-secrets-manager` | Registry |
| 7 | `aws:` | Misc |
| 8 | `service: SecretsManager` | Registry |
| 9 | `region: eu-west-3` | Misc |
| 13 | `name: external-secrets` | Registry |
| 14 | `namespace: external-secrets` | Registry |

### infrastructure/kubernetes/base/external-secrets/kustomization.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 3 | `namespace: external-secrets` | Registry |

### infrastructure/kubernetes/base/external-secrets/namespace.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 4 | `name: external-secrets` | Registry |
| 7 | `layer: external-secrets` | Registry |

### infrastructure/kubernetes/base/external-secrets/serviceaccount.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 4 | `name: external-secrets` | Registry |
| 5 | `namespace: external-secrets` | Registry |
| 9 | `eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/REPLACE_ME` | IAM |

### infrastructure/kubernetes/base/gateway/external-secret-gateway.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 1 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 9 | `name: aws-secrets-manager` | Registry |
| 10 | `kind: ClusterSecretStore` | Registry |

### infrastructure/kubernetes/base/gateway/ingress.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 16 | `- host: REPLACE_ME_OVERLAY` | Misc |

### infrastructure/kubernetes/base/kustomization.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 9 | `- external-secrets` | Registry |

### infrastructure/kubernetes/base/observability/configmap-prometheus.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 11 | `cluster: REPLACE_ME_CLUSTER` | Misc |
| 12 | `environment: REPLACE_ME_ENV` | Misc |

### infrastructure/kubernetes/base/observability/external-secret-grafana.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 1 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 9 | `name: aws-secrets-manager` | Registry |
| 10 | `kind: ClusterSecretStore` | Registry |

### infrastructure/kubernetes/base/security/external-secret-vault.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 1 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 9 | `name: aws-secrets-manager` | Registry |
| 10 | `kind: ClusterSecretStore` | Registry |

### infrastructure/kubernetes/overlays/dev/kustomization.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 27 | `- path: patches/disable-external-secrets.yaml` | Registry |
| 101 | `namespace: external-secrets` | Registry |
| 105 | `value: dev-external-secrets` | Registry |
| 143 | `name: external-secrets` | Registry |
| 147 | `value: dev-external-secrets` | Registry |
| 239 | `- name: ACCOUNT_ID.dkr.ecr.eu-west-3.amazonaws.com/diffusion-queue-service` | Registry |

### infrastructure/kubernetes/overlays/dev/local-secrets.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 3 | `# La production utilise External Secrets Operator + AWS Secrets Manager` | Registry |

### infrastructure/kubernetes/overlays/dev/patches/disable-external-secrets.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 1 | `# Supprime tous les ExternalSecret et ClusterSecretStore en dev` | Registry |
| 2 | `# (pas d'AWS Secrets Manager sur Docker Desktop / Minikube)` | Registry |
| 5 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 12 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 19 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 26 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 33 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 40 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 47 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 48 | `kind: ClusterSecretStore` | Registry |
| 50 | `name: aws-secrets-manager` | Registry |
| 56 | `name: external-secrets` | Registry |
| 57 | `namespace: external-secrets` | Registry |

### infrastructure/kubernetes/overlays/dev/patches/nodeports.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 3 | `# En staging et prod, l'accès se fait via l'Ingress ALB (étape 8)` | Networking |

### infrastructure/kubernetes/overlays/prod/kustomization.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 20 | `- path: patches/storage-class-gp3.yaml` | Storage |
| 22 | `- path: patches/external-secrets-env.yaml` | Registry |
| 54 | `namespace: external-secrets` | Registry |
| 58 | `value: prod-external-secrets` | Registry |
| 96 | `name: external-secrets` | Registry |
| 100 | `value: prod-external-secrets` | Registry |
| 185 | `- name: ACCOUNT_ID.dkr.ecr.eu-west-3.amazonaws.com/diffusion-queue-service` | Registry |
| 186 | `newName: ACCOUNT_ID.dkr.ecr.eu-west-3.amazonaws.com/diffusion-queue-service` | Registry |

### infrastructure/kubernetes/overlays/prod/patches/external-secrets-env.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 2 | `# et configurer l'ARN IRSA du ServiceAccount` | Misc |
| 4 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 20 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 36 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 56 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 68 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 80 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 95 | `name: external-secrets` | Registry |
| 96 | `namespace: external-secrets` | Registry |
| 98 | `eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/eks-prod-external-secrets` | IAM |

### infrastructure/kubernetes/overlays/prod/patches/storage-class-gp3.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 7 | `storageClassName: gp3` | Storage |
| 18 | `storageClassName: gp3` | Storage |
| 29 | `storageClassName: gp3` | Storage |
| 40 | `storageClassName: gp3` | Storage |
| 48 | `storageClassName: gp3` | Storage |
| 56 | `storageClassName: gp3` | Storage |

### infrastructure/kubernetes/overlays/staging/kustomization.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 19 | `- path: patches/storage-class-gp3.yaml` | Storage |
| 20 | `- path: patches/external-secrets-env.yaml` | Registry |
| 52 | `namespace: external-secrets` | Registry |
| 56 | `value: staging-external-secrets` | Registry |
| 94 | `name: external-secrets` | Registry |
| 98 | `value: staging-external-secrets` | Registry |
| 182 | `- name: ACCOUNT_ID.dkr.ecr.eu-west-3.amazonaws.com/diffusion-queue-service` | Registry |
| 183 | `newName: ACCOUNT_ID.dkr.ecr.eu-west-3.amazonaws.com/diffusion-queue-service` | Registry |

### infrastructure/kubernetes/overlays/staging/patches/external-secrets-env.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 2 | `# et configurer l'ARN IRSA du ServiceAccount` | Misc |
| 4 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 20 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 36 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 56 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 68 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 80 | `apiVersion: external-secrets.io/v1beta1` | Registry |
| 95 | `name: external-secrets` | Registry |
| 96 | `namespace: external-secrets` | Registry |
| 98 | `eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/eks-staging-external-secrets` | IAM |

### infrastructure/kubernetes/overlays/staging/patches/storage-class-gp3.yaml
| Ligne | Contenu | Catégorie |
|---|---|---|
| 7 | `storageClassName: gp3` | Storage |
| 15 | `storageClassName: gp3` | Storage |
| 23 | `storageClassName: gp3` | Storage |
| 31 | `storageClassName: gp3` | Storage |
| 39 | `storageClassName: gp3` | Storage |
| 47 | `storageClassName: gp3` | Storage |

### infrastructure/kubernetes/README.md
| Ligne | Contenu | Catégorie |
|---|---|---|
| 3 | `Ce dossier contient la configuration de déploiement pour le cluster Kubernetes cible (AWS EKS). Le déploiement est géré via **Kustomize** pour permettre une configuration DRY entre les environnements.` | Misc |
| 43 | `\| **Storage Class (PVC)** \| Standard (base) \| `gp3` (AWS) \| `gp3` (AWS) + Tailles augmentées \|` | Storage |
| 72 | `Les secrets sont gérés par **External Secrets Operator** (AWS Secrets Manager). Voir [docs/security/SECRETS_MANAGEMENT.md](../../docs/security/SECRETS_MANAGEMENT.md).` | Registry |
| 79 | `- **Secret** : données sensibles (mots de passe, clés d'API, tokens). Gérés via External Secrets Operator depuis AWS Secrets Manager. Voir [docs/security/SECRETS_MANAGEMENT.md](../../docs/security/SEC` | Registry |
| 182 | `Internet → Ingress ALB (étape 8)` | Networking |

### infrastructure/queue-service/package-lock.json
| Ligne | Contenu | Catégorie |
|---|---|---|
| 1629 | `"integrity": "sha512-TkRKr9sUTxEH8MdfuCSP7VizJyzRNMjj2J2do2Jr3Kym598JVdEksuzPQCnlFPW4ky9Q+iA+ma9BGm06XQBy8g==",` | Misc |

### docs/k8s/SERVICES_CONVENTIONS.md
| Ligne | Contenu | Catégorie |
|---|---|---|
| 15 | `\| `LoadBalancer` \| **À éviter** — préférer Ingress ALB (étape 8). Coûteux sur AWS (1 ELB par Service) \| — \|` | Networking |
| 21 | `- **LoadBalancer direct → interdit** en dehors de l'Ingress Controller. L'exposition publique passe uniquement par l'Ingress ALB (étape 8).` | Networking |
| 51 | `4. **`appProtocol:`** — renseigner quand applicable (aide les Service Mesh, AWS ALB, et le debugging).` | Networking |
| 103 | `### Annotations ALB (étape 8)` | Networking |
| 105 | `Les annotations `service.beta.kubernetes.io/aws-load-balancer-*` seront ajoutées **uniquement** sur les Services de type LoadBalancer dans l'overlay prod à l'étape 8. Elles ne doivent pas apparaître s` | Misc |
| 121 | `\| `kong-proxy` \| 80 \| Ingress Controller, Ingress ALB \| — \|` | Networking |

### docs/security/SECRETS_AUDIT.md
| Ligne | Contenu | Catégorie |
|---|---|---|
| 60 | `1. **Générer de nouveaux secrets** avec `scripts/aws-create-secrets.sh prod`` | Registry |

### docs/security/SECRETS_MANAGEMENT.md
| Ligne | Contenu | Catégorie |
|---|---|---|
| 7 | `│                    AWS Secrets Manager                       │` | Registry |
| 19 | `│           ClusterSecretStore: aws-secrets-manager             │` | Registry |
| 20 | `│           Auth: IRSA (ServiceAccount → IAM Role)             │` | IAM |
| 37 | `## B. Pourquoi External Secrets Operator + AWS Secrets Manager` | Registry |
| 40 | `2. **Rotation automatique** : Mise à jour via AWS SM + `refreshInterval` d'ESO.` | Secrets |
| 41 | `3. **Audit trail** : AWS CloudTrail enregistre chaque accès aux secrets.` | Registry |
| 43 | `5. **IRSA** : Authentification sans access keys grâce à IAM Roles for Service Accounts.` | IAM |
| 49 | `helm repo add external-secrets https://charts.external-secrets.io` | Registry |
| 53 | `helm install external-secrets external-secrets/external-secrets \` | Registry |
| 54 | `--namespace external-secrets \` | Registry |
| 59 | `kubectl -n external-secrets get pods` | Registry |
| 64 | `> `ClusterSecretStore` doivent exister pour que Kustomize puisse appliquer` | Registry |
| 67 | `## D. Création des secrets dans AWS Secrets Manager` | Registry |
| 73 | `./scripts/aws-create-secrets.sh prod` | Registry |
| 76 | `./scripts/aws-create-secrets.sh staging` | Registry |
| 80 | `- Vérifie que `aws` CLI est configuré` | Misc |
| 82 | `- Les pousse dans AWS SM au bon path (`diffusion/<env>/<domain>`)` | Misc |
| 86 | `## E. Configuration IRSA` | Misc |
| 90 | `1. **Créer le OIDC Provider** pour le cluster EKS :` | Misc |
| 92 | `eksctl utils associate-iam-oidc-provider \` | IAM |
| 104 | `"secretsmanager:GetSecretValue",` | Registry |
| 105 | `"secretsmanager:DescribeSecret"` | Registry |
| 107 | `"Resource": "arn:aws:secretsmanager:eu-west-3:ACCOUNT_ID:secret:diffusion/*"` | IAM |
| 119 | `"Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.eu-west-3.amazonaws.com/id/OIDC_ID"` | IAM |
| 124 | `"oidc.eks.eu-west-3.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:external-secrets:external-secrets"` | Registry |
| 132 | ``overlays/<env>/patches/external-secrets-env.yaml`` | Registry |
| 136 | `1. Créer le secret dans AWS SM : `aws secretsmanager create-secret --name diffusion/<env>/<domain> --secret-string '{"KEY":"value"}'`` | Registry |
| 144 | `### Rotation via AWS SM (recommandé)` | Misc |
| 146 | `1. Mettre à jour la valeur dans AWS SM :` | Misc |
| 148 | `aws secretsmanager update-secret \` | Registry |
| 167 | `Sur Docker Desktop / Minikube, il n'y a pas d'AWS Secrets Manager.` | Registry |
| 169 | `- **Supprime** les ExternalSecret et ClusterSecretStore via `patches/disable-external-secrets.yaml`` | Registry |
| 178 | `**Action immédiate** : Exécuter `./scripts/aws-create-secrets.sh prod` pour` | Registry |

## Étape 3 — Inventaire structuré (passe 2)

### Tableau A — Services exposés
| Fichier | Service name | Type | Port | Annotations cloud-spécifiques |
|---|---|---|---|---|
| `infrastructure/kubernetes/base/app/external-services.yaml` | `postgres` | `ExternalName` | `5432` | `-` |
| `infrastructure/kubernetes/base/app/n8n-main.yaml` | `n8n-main` | `RollingUpdate` | `5678` | `-` |
| `infrastructure/kubernetes/base/app/queue-service.yaml` | `queue-service` | `RollingUpdate` | `3002` | `-` |
| `infrastructure/kubernetes/base/data/postgres.yaml` | `postgres` | `OnDelete` | `5432` | `-` |
| `infrastructure/kubernetes/base/data/redis.yaml` | `redis` | `RollingUpdate` | `6379` | `-` |
| `infrastructure/kubernetes/base/gateway/external-services.yaml` | `n8n-main` | `ExternalName` | `5678` | `-` |
| `infrastructure/kubernetes/base/gateway/kong.yaml` | `kong` | `RollingUpdate` | `8001` | `-` |
| `infrastructure/kubernetes/base/observability/external-services.yaml` | `postgres-exporter` | `ExternalName` | `9187` | `-` |
| `infrastructure/kubernetes/base/observability/monitoring.yaml` | `prometheus` | `RuntimeDefault` | `9090` | `-` |
| `infrastructure/kubernetes/base/security/vault.yaml` | `vault` | `RuntimeDefault` | `8200` | `-` |
| `infrastructure/kubernetes/overlays/dev/kustomization.yaml` | `queue-service` | `ClusterIP` | `8200` | `-` |
| `infrastructure/kubernetes/overlays/dev/patches/nodeports.yaml` | `n8n-main-nodeport` | `NodePort` | `5678` | `-` |
| `infrastructure/kubernetes/overlays/prod/kustomization.yaml` | `prometheus-config` | `ClusterIP` | `?` | `-` |
| `infrastructure/kubernetes/overlays/staging/kustomization.yaml` | `prometheus-config` | `ClusterIP` | `?` | `-` |

### Tableau B — PVC et StorageClass
| Fichier | PVC name | StorageClass | Taille | accessMode |
|---|---|---|---|---|
| `infrastructure/kubernetes/base/data/backups-pvc.yaml` | `backups-pvc` | `local-path` | `10Gi` | `?` |
| `infrastructure/kubernetes/base/data/pvcs.yaml` | `postgres-pvc` | `?` | `10Gi` | `ReadWriteOnce` |
| `infrastructure/kubernetes/base/observability/pvcs.yaml` | `prometheus-pvc` | `?` | `5Gi` | `ReadWriteOnce` |
| `infrastructure/kubernetes/base/security/pvcs.yaml` | `vault-pvc` | `?` | `1Gi` | `ReadWriteOnce` |
| `infrastructure/kubernetes/overlays/prod/patches/storage-class-gp3.yaml` | `postgres-pvc` | `gp3` | `50Gi` | `?` |
| `infrastructure/kubernetes/overlays/prod/patches/storage-class-gp3.yaml` | `postgres-pvc` | `gp3 (patch)` | `?` | `?` |
| `infrastructure/kubernetes/overlays/staging/patches/storage-class-gp3.yaml` | `postgres-pvc` | `gp3` | `?` | `?` |
| `infrastructure/kubernetes/overlays/staging/patches/storage-class-gp3.yaml` | `postgres-pvc` | `gp3 (patch)` | `?` | `?` |

### Tableau C — Images de containers
| Fichier | Container name | Image | Tag | Registry |
|---|---|---|---|---|
| `infrastructure/kubernetes/base/app/n8n-main.yaml` | `n8n-main` | `n8nio/n8n:2.18.7` | `2.18.7` | `Docker Hub` |
| `infrastructure/kubernetes/base/app/n8n-worker.yaml` | `n8n-worker` | `n8nio/n8n:2.18.7` | `2.18.7` | `Docker Hub` |
| `infrastructure/kubernetes/base/app/queue-service.yaml` | `?` | `ACCOUNT_ID.dkr.ecr.eu-west-3.amazonaws.com/diffusion-queue-service:v1.0.0` | `v1.0.0` | `ACCOUNT_ID.dkr.ecr.eu-west-3.amazonaws.com` |
| `infrastructure/kubernetes/base/data/backups-cronjobs.yaml` | `pg-backup` | `postgres:16.6-alpine` | `16.6-alpine` | `Docker Hub` |
| `infrastructure/kubernetes/base/data/backups-cronjobs.yaml` | `pg-backup` | `redis:7.4.1-alpine` | `7.4.1-alpine` | `Docker Hub` |
| `infrastructure/kubernetes/base/data/flyway.yaml` | `flyway` | `flyway/flyway:10-alpine` | `10-alpine` | `Docker Hub` |
| `infrastructure/kubernetes/base/data/postgres.yaml` | `postgres` | `postgres:16.6-alpine` | `16.6-alpine` | `Docker Hub` |
| `infrastructure/kubernetes/base/data/postgres.yaml` | `postgres` | `prometheuscommunity/postgres-exporter:v0.15.0` | `v0.15.0` | `Docker Hub` |
| `infrastructure/kubernetes/base/data/redis.yaml` | `redis` | `redis:7.4.1-alpine` | `7.4.1-alpine` | `Docker Hub` |
| `infrastructure/kubernetes/base/data/redis.yaml` | `redis` | `oliver006/redis_exporter:v1.58.0` | `v1.58.0` | `Docker Hub` |
| `infrastructure/kubernetes/base/gateway/kong.yaml` | `substitute-secrets` | `busybox:1.36` | `1.36` | `Docker Hub` |
| `infrastructure/kubernetes/base/gateway/kong.yaml` | `substitute-secrets` | `kong:3.6.1` | `3.6.1` | `Docker Hub` |
| `infrastructure/kubernetes/base/observability/monitoring.yaml` | `prometheus` | `prom/prometheus:v2.51.0` | `v2.51.0` | `Docker Hub` |
| `infrastructure/kubernetes/base/observability/monitoring.yaml` | `prometheus` | `grafana/grafana:10.4.18` | `10.4.18` | `Docker Hub` |
| `infrastructure/kubernetes/base/security/vault.yaml` | `vault` | `hashicorp/vault:1.15.6` | `1.15.6` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/dev/kustomization.yaml` | `?` | `n8nio/n8n` | `"2.18.7"` | `n8nio` |
| `infrastructure/kubernetes/overlays/dev/kustomization.yaml` | `?` | `postgres` | `"16.6-alpine"` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/dev/kustomization.yaml` | `?` | `redis` | `"7.4.1-alpine"` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/dev/kustomization.yaml` | `?` | `diffusion-queue-service` | `"dev"` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/dev/kustomization.yaml` | `?` | `kong` | `"3.6.1"` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/dev/kustomization.yaml` | `?` | `hashicorp/vault` | `"1.15.6"` | `hashicorp` |
| `infrastructure/kubernetes/overlays/dev/kustomization.yaml` | `?` | `prom/prometheus` | `"v2.51.0"` | `prom` |
| `infrastructure/kubernetes/overlays/dev/kustomization.yaml` | `?` | `grafana/grafana` | `"10.4.18"` | `grafana` |
| `infrastructure/kubernetes/overlays/dev/patches/flyway-wait-postgres.yaml` | `wait-for-postgres` | `postgres:16.6-alpine` | `16.6-alpine` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/dev/patches/kong-dev.yaml` | `substitute-secrets` | `kong:3.6.1` | `3.6.1` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/dev/patches/kong-dev.yaml` | `substitute-secrets` | `kong:3.6.1` | `3.6.1` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/dev/patches/postgres-dev.yaml` | `init-postgres-permissions` | `postgres:16.6-alpine` | `16.6-alpine` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/dev/patches/queue-service-image-local.yaml` | `queue-service` | `diffusion-queue-service:dev` | `dev` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/prod/kustomization.yaml` | `?` | `n8nio/n8n` | `2.18.7` | `n8nio` |
| `infrastructure/kubernetes/overlays/prod/kustomization.yaml` | `?` | `postgres` | `16.6-alpine` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/prod/kustomization.yaml` | `?` | `redis` | `7.4.1-alpine` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/prod/kustomization.yaml` | `?` | `ACCOUNT_ID.dkr.ecr.eu-west-3.amazonaws.com/diffusion-queue-service` | `v1.0.0` | `ACCOUNT_ID.dkr.ecr.eu-west-3.amazonaws.com` |
| `infrastructure/kubernetes/overlays/prod/kustomization.yaml` | `?` | `kong` | `3.6.1` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/prod/kustomization.yaml` | `?` | `hashicorp/vault` | `1.15.6` | `hashicorp` |
| `infrastructure/kubernetes/overlays/prod/kustomization.yaml` | `?` | `prom/prometheus` | `v2.51.0` | `prom` |
| `infrastructure/kubernetes/overlays/prod/kustomization.yaml` | `?` | `grafana/grafana` | `10.4.18` | `grafana` |
| `infrastructure/kubernetes/overlays/staging/kustomization.yaml` | `?` | `n8nio/n8n` | `2.18.7` | `n8nio` |
| `infrastructure/kubernetes/overlays/staging/kustomization.yaml` | `?` | `postgres` | `16.6-alpine` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/staging/kustomization.yaml` | `?` | `redis` | `7.4.1-alpine` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/staging/kustomization.yaml` | `?` | `ACCOUNT_ID.dkr.ecr.eu-west-3.amazonaws.com/diffusion-queue-service` | `staging-latest` | `ACCOUNT_ID.dkr.ecr.eu-west-3.amazonaws.com` |
| `infrastructure/kubernetes/overlays/staging/kustomization.yaml` | `?` | `kong` | `3.6.1` | `Docker Hub` |
| `infrastructure/kubernetes/overlays/staging/kustomization.yaml` | `?` | `hashicorp/vault` | `1.15.6` | `hashicorp` |
| `infrastructure/kubernetes/overlays/staging/kustomization.yaml` | `?` | `prom/prometheus` | `v2.51.0` | `prom` |
| `infrastructure/kubernetes/overlays/staging/kustomization.yaml` | `?` | `grafana/grafana` | `10.4.18` | `grafana` |

### Tableau D — ServiceAccounts avec annotations
| Fichier | ServiceAccount name | Namespace | Annotation | Valeur |
|---|---|---|---|---|
| `infrastructure/kubernetes/base/external-secrets/serviceaccount.yaml` | `external-secrets` | `external-secrets` | `-` | `-` |
| `infrastructure/kubernetes/base/external-secrets/serviceaccount.yaml` | `external-secrets` | `external-secrets` | `eks.amazonaws.com/role-arn` | `arn:aws:iam::ACCOUNT_ID:role/REPLACE_ME` |
| `infrastructure/kubernetes/overlays/dev/patches/disable-external-secrets.yaml` | `external-secret-data` | `data` | `-` | `-` |
| `infrastructure/kubernetes/overlays/prod/patches/external-secrets-env.yaml` | `external-secret-data` | `data` | `-` | `-` |
| `infrastructure/kubernetes/overlays/prod/patches/external-secrets-env.yaml` | `external-secret-data` | `data` | `eks.amazonaws.com/role-arn` | `arn:aws:iam::ACCOUNT_ID:role/eks-prod-external-secrets` |
| `infrastructure/kubernetes/overlays/staging/patches/external-secrets-env.yaml` | `external-secret-data` | `data` | `-` | `-` |
| `infrastructure/kubernetes/overlays/staging/patches/external-secrets-env.yaml` | `external-secret-data` | `data` | `eks.amazonaws.com/role-arn` | `arn:aws:iam::ACCOUNT_ID:role/eks-staging-external-secrets` |

## Étape 4 — Matrice de mapping AWS → OVH

| Concept AWS | Ressource OVH équivalente | Action requise | Étape du plan |
|---|---|---|---|
| AWS Secrets Manager / ESO | HashiCorp Vault + Vault Agent Injector | Déployer Vault, configurer Injector | Étape 2 |
| ECR | GitHub Container Registry (GHCR) | Mettre à jour les Kustomizations, CI/CD | Étape 3 |
| ACM | cert-manager + Let's Encrypt (DNS-01 via OVH) | Déployer cert-manager, Issuer | Étape 4 |
| AWS ALB Controller | Ingress Controller managé MKS (nginx) | Mettre à jour les Ingress, enlever annotations ALB | Étape 4 |
| IRSA | Vault Kubernetes Auth method | Configurer Vault Auth pour K8s | Étape 2 |
| EBS gp3 | csi-cinder-high-speed | Mettre à jour les patches de StorageClass | Étape 1 |
| Route53 | OVH DNS Zone | Migrer la gestion DNS | Étape 4 |
| CloudWatch Logs | reporté (Prometheus + Grafana suffisent) | Aucune | N/A |
| EKS Managed Node Group | OVH MKS Node Pool | Créer les Node Pools correspondants | Étape 1 |

## Étape 5 — Liste des dettes techniques

- infrastructure\docker-compose.dev.yml:69 : Image utilise le tag `:latest`
- infrastructure\kubernetes\overlays\dev\local-secrets.yaml:7 : Secret défini en clair dans le repo
- infrastructure\kubernetes\overlays\dev\local-secrets.yaml:17 : Secret défini en clair dans le repo
- infrastructure\kubernetes\overlays\dev\local-secrets.yaml:27 : Secret défini en clair dans le repo
- infrastructure\kubernetes\overlays\dev\local-secrets.yaml:40 : Secret défini en clair dans le repo
- infrastructure\kubernetes\overlays\dev\local-secrets.yaml:49 : Secret défini en clair dans le repo
- infrastructure\kubernetes\overlays\dev\local-secrets.yaml:58 : Secret défini en clair dans le repo
- Note: Les fichiers YAML sans `resources.requests` ou `resources.limits` ou sans probes complètes nécessitent une revue globale car ils sont omis de la majorité des manifests de base.

*Note: Le dossier `infrastructure/terraform/` est absent de ce repository.*
