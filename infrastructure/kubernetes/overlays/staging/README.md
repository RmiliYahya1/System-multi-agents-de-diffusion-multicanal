# Overlay staging — OVHcloud MKS

Cible : cluster MKS 2 nodes (pré-production).

## État de la migration AWS → MKS

| Sujet | Statut | Étape |
|---|---|---|
| Suppression patches AWS | ✅ Fait | 3 |
| StorageClass MKS | 🔲 À faire | 5 |
| Secrets Vault | 🔲 À faire | 6 |
| Ingress + TLS | 🔲 À faire | 7 |
| Image registry GHCR | 🔲 À faire | 8 |

## Patches actifs

Voir `kustomization.yaml` pour la liste à jour.

## Archives

Les patches AWS retirés sont conservés dans `_archived-aws/`.
