#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Phase 5 — Script d'initialisation de HashiCorp Vault
# ═══════════════════════════════════════════════════════════════
#
# Ce script pousse les credentials de démonstration dans le
# moteur KV v2 de Vault après le démarrage de docker compose.
#
# Usage:
#   docker exec diffusion-vault sh /vault/scripts/init-vault.sh
#   OU
#   ./init-vault.sh  (si exécuté depuis l'extérieur avec VAULT_ADDR configuré)
#
# ═══════════════════════════════════════════════════════════════

set -e

# Configuration
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="V4ult_R00t_T0k3n_2026!"

echo "═══════════════════════════════════════════════════"
echo " Vault Init — Système de Diffusion (Phase 5)"
echo "═══════════════════════════════════════════════════"
echo ""
echo "→ VAULT_ADDR: $VAULT_ADDR"
echo ""

# ─── 1. Activer le moteur KV v2 (si pas déjà actif) ─────────
echo "[1/3] Activation du moteur secret KV v2..."
vault secrets enable -path=secret kv-v2 2>/dev/null || echo "  → Moteur 'secret/' déjà actif (OK)"

# ─── 2. Pousser le credential de démonstration ───────────────
echo "[2/3] Insertion des credentials de démonstration..."

# CRED-META-01 — Credential Facebook/Instagram de démo
vault kv put secret/credentials/CRED-META-01 \
  credential_ref="CRED-META-01" \
  client_id="1" \
  platform="facebook" \
  access_token="EAAxxxDEMO_ACCESS_TOKEN_FACEBOOK_2026xxx" \
  refresh_token="" \
  client_app_id="579564268565837" \
  client_secret="DEMO_CLIENT_SECRET_FB_2026" \
  expires_at="2026-12-31T23:59:59Z" \
  tenant_id="1"

echo "  ✅ CRED-META-01 (Facebook/Instagram) inséré"

# CRED-LINKEDIN-01 — Credential LinkedIn de démo
vault kv put secret/credentials/CRED-LINKEDIN-01 \
  credential_ref="CRED-LINKEDIN-01" \
  client_id="1" \
  platform="linkedin" \
  access_token="AQXxxDEMO_ACCESS_TOKEN_LINKEDIN_2026xxx" \
  refresh_token="AQXxxDEMO_REFRESH_TOKEN_LINKEDIN_2026xxx" \
  client_app_id="86vkxxxxxx" \
  client_secret="DEMO_CLIENT_SECRET_LI_2026" \
  expires_at="2026-12-31T23:59:59Z" \
  tenant_id="1"

echo "  ✅ CRED-LINKEDIN-01 (LinkedIn) inséré"

# ─── 3. Vérification ─────────────────────────────────────────
echo "[3/3] Vérification des secrets..."

echo ""
echo "--- CRED-META-01 ---"
vault kv get -format=json secret/credentials/CRED-META-01 | grep -o '"credential_ref":"[^"]*"'

echo ""
echo "--- CRED-LINKEDIN-01 ---"
vault kv get -format=json secret/credentials/CRED-LINKEDIN-01 | grep -o '"credential_ref":"[^"]*"'

echo ""
echo "═══════════════════════════════════════════════════"
echo " ✅ Vault initialisé avec succès !"
echo ""
echo " Pour vérifier manuellement :"
echo "   vault kv get secret/credentials/CRED-META-01"
echo "   vault kv get secret/credentials/CRED-LI-01"
echo ""
echo " Pour ajouter un nouveau credential :"
echo "   vault kv put secret/credentials/CRED-XXX-NN \\"
echo "     credential_ref=CRED-XXX-NN \\"
echo "     client_id=42 platform=facebook \\"
echo "     access_token=EAAxxx..."
echo "═══════════════════════════════════════════════════"
