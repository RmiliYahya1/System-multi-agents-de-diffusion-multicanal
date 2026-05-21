# Overlay prod — OVHcloud MKS

Cible : cluster MKS 3 nodes HA (production).

## État de la migration AWS → MKS

| Sujet | Statut | Étape |
|---|---|---|
| Suppression patches AWS | ✅ Fait | 3 |
| StorageClass MKS | 🔲 À faire | 5 |
| Secrets Vault | 🔲 À faire | 6 |
| Ingress + TLS | 🔲 À faire | 7 |
| Image registry GHCR | 🔲 À faire | 8 |
| Anti-affinity / topology | 🔲 À faire | 9 |
| Target SLA (99.9%) | 🔲 À définir | — |

## Patches actifs

Voir `kustomization.yaml` pour la liste à jour.
Le patch `hpa-prod.yaml` (HPA n8n-worker) est cloud-neutre et reste actif.

## Archives

Les patches AWS retirés sont conservés dans `_archived-aws/`.
