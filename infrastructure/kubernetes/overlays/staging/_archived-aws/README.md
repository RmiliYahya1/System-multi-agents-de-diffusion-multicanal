# Archive — Patches AWS (pre-migration)

Ce dossier contient les patches Kustomize qui ciblaient AWS EKS, archivés
le 21 mai 2026 lors de la migration vers OVHcloud MKS.

Ces fichiers ne sont **pas** consommés par Kustomize (le préfixe `_` du
dossier les exclut de l'arborescence active). Ils sont conservés à des
fins de référence historique pour le rapport de projet.

## Contenu

| Fichier | Rôle initial |
|---|---|
| `external-secrets-env.yaml.bak` | Configurait ESO + ARN IRSA AWS pour Secrets Manager |
| `storage-class-gp3.yaml.bak` | Patchait les PVC vers StorageClass `gp3` (EBS) |

## Remplacés par

Voir `../patches/secrets-vault.yaml` et `../patches/storage-class-mks.yaml`
(créés aux étapes 5 et 6 du plan de migration).
