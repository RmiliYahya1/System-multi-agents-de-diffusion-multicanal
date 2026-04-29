#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Script de création des secrets dans AWS Secrets Manager
# Usage: ./aws-create-secrets.sh <env>  (prod | staging)
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

ENV="${1:-}"
REGION="${AWS_DEFAULT_REGION:-eu-west-3}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/tmp/aws-create-secrets-${ENV}-${TIMESTAMP}.log"

# ─── Validation ─────────────────────────────────────────────
if [[ -z "$ENV" || ( "$ENV" != "prod" && "$ENV" != "staging" ) ]]; then
  echo "❌ Usage: $0 <prod|staging>"
  exit 1
fi

if ! command -v aws &>/dev/null; then
  echo "❌ aws CLI non trouvé. Installez-le : https://aws.amazon.com/cli/"
  exit 1
fi

if ! aws sts get-caller-identity &>/dev/null; then
  echo "❌ aws CLI non configuré. Lancez 'aws configure' d'abord."
  exit 1
fi

echo "═══════════════════════════════════════════════════"
echo " AWS Secrets Manager — Création pour [$ENV]"
echo " Région: $REGION"
echo " Log: $LOG_FILE"
echo "═══════════════════════════════════════════════════"
echo ""

# ─── Fonctions utilitaires ──────────────────────────────────
generate_password() {
  openssl rand -base64 32 | tr -d '/+=' | head -c 32
}

generate_hex_key() {
  openssl rand -hex 32
}

create_or_update_secret() {
  local secret_name="$1"
  local secret_value="$2"

  echo -n "  → $secret_name ... "

  if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$REGION" &>/dev/null; then
    aws secretsmanager update-secret \
      --secret-id "$secret_name" \
      --secret-string "$secret_value" \
      --region "$REGION" >> "$LOG_FILE" 2>&1
    echo "UPDATED ✅"
  else
    aws secretsmanager create-secret \
      --name "$secret_name" \
      --secret-string "$secret_value" \
      --region "$REGION" >> "$LOG_FILE" 2>&1
    echo "CREATED ✅"
  fi
}

# ─── Génération des secrets ─────────────────────────────────
echo "[1/6] Génération des nouveaux secrets aléatoires..."

POSTGRES_PASSWORD=$(generate_password)
POSTGRES_USER="diffusion_admin"
POSTGRES_DB="diffusion_db"
REDIS_PASSWORD=$(generate_password)
N8N_ENCRYPTION_KEY=$(generate_hex_key)
KONG_JWT_SECRET=$(generate_password)
GF_ADMIN_PASSWORD=$(generate_password)
VAULT_TOKEN=$(generate_password)
PGADMIN_EMAIL="admin@diffusion.iaweb.dev"
PGADMIN_PASSWORD=$(generate_password)

echo "  ✅ Tous les secrets générés (non affichés par sécurité)"
echo ""

# ─── Création dans AWS SM ───────────────────────────────────
echo "[2/6] Secret: diffusion/$ENV/database"
create_or_update_secret "diffusion/$ENV/database" \
  "{\"POSTGRES_PASSWORD\":\"$POSTGRES_PASSWORD\",\"POSTGRES_USER\":\"$POSTGRES_USER\",\"POSTGRES_DB\":\"$POSTGRES_DB\"}"

echo "[3/6] Secret: diffusion/$ENV/cache"
create_or_update_secret "diffusion/$ENV/cache" \
  "{\"REDIS_PASSWORD\":\"$REDIS_PASSWORD\"}"

echo "[4/6] Secret: diffusion/$ENV/n8n"
create_or_update_secret "diffusion/$ENV/n8n" \
  "{\"N8N_ENCRYPTION_KEY\":\"$N8N_ENCRYPTION_KEY\"}"

echo "[5/6] Secret: diffusion/$ENV/gateway"
create_or_update_secret "diffusion/$ENV/gateway" \
  "{\"KONG_JWT_SECRET\":\"$KONG_JWT_SECRET\"}"

echo "[6/6] Secrets secondaires..."
create_or_update_secret "diffusion/$ENV/grafana" \
  "{\"GF_ADMIN_PASSWORD\":\"$GF_ADMIN_PASSWORD\"}"

create_or_update_secret "diffusion/$ENV/vault" \
  "{\"VAULT_TOKEN\":\"$VAULT_TOKEN\"}"

create_or_update_secret "diffusion/$ENV/pgadmin" \
  "{\"PGADMIN_EMAIL\":\"$PGADMIN_EMAIL\",\"PGADMIN_PASSWORD\":\"$PGADMIN_PASSWORD\"}"

# ─── Récapitulatif ──────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════"
echo " ✅ Tous les secrets créés/mis à jour pour [$ENV]"
echo ""
echo " Secrets créés :"
echo "   • diffusion/$ENV/database   (POSTGRES_PASSWORD, POSTGRES_USER, POSTGRES_DB)"
echo "   • diffusion/$ENV/cache      (REDIS_PASSWORD)"
echo "   • diffusion/$ENV/n8n        (N8N_ENCRYPTION_KEY)"
echo "   • diffusion/$ENV/gateway    (KONG_JWT_SECRET)"
echo "   • diffusion/$ENV/grafana    (GF_ADMIN_PASSWORD)"
echo "   • diffusion/$ENV/vault      (VAULT_TOKEN)"
echo "   • diffusion/$ENV/pgadmin    (PGADMIN_EMAIL, PGADMIN_PASSWORD)"
echo ""
echo " Log complet : $LOG_FILE"
echo " ⚠️  Les valeurs en clair ne sont PAS affichées."
echo "═══════════════════════════════════════════════════"
