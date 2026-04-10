-- ═══════════════════════════════════════════════════════════════════
-- MIGRATION PHASE 1 — Schéma complet du Système de Diffusion
-- ═══════════════════════════════════════════════════════════════════
-- 
-- Ce script crée l'intégralité du schéma PostgreSQL pour remplacer
-- les 4 tables Airtable (2 bases) par une base de données unifiée.
--
-- Ordre d'exécution :
--   1. Schema
--   2. Credentials      (pas de dépendance)
--   3. Channel Config    (pas de dépendance)
--   4. Jobs              (FK → credentials)
--   5. Log Events        (partitionnée, pas de FK)
--   6. Triggers
--   7. Fonctions utilitaires
--   8. Vues
--   9. Données initiales (seed)
--
-- Exécution : psql -h localhost -U diffusion_admin -d diffusion_db -f 001_init_schema.sql
-- ═══════════════════════════════════════════════════════════════════

BEGIN;

-- ───────────────────────────────────────────────────
-- 1. SCHEMA
-- ───────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS diffusion;

-- Timezone par défaut pour la session
SET timezone = 'Africa/Casablanca';


-- ───────────────────────────────────────────────────
-- 2. TABLE: diffusion.credentials
-- ───────────────────────────────────────────────────
-- Stocke les tokens OAuth des plateformes sociales.
-- Créée EN PREMIER car diffusion.jobs y fait référence (FK).
-- ───────────────────────────────────────────────────

CREATE TABLE diffusion.credentials (
    id                  BIGSERIAL     PRIMARY KEY,
    
    -- Identifiant métier
    credential_ref      VARCHAR(50)   UNIQUE NOT NULL,
    client_id           BIGINT        NOT NULL,
    platform            VARCHAR(20)   NOT NULL
                        CHECK (platform IN ('facebook', 'instagram', 'linkedin')),
    
    -- Tokens OAuth (Phase 5 : chiffrement applicatif)
    access_token        TEXT          NOT NULL,
    refresh_token       TEXT,
    client_app_id       VARCHAR(100),
    client_secret       TEXT,

    tenant_id           BIGINT        NOT NULL,
    
    -- Expiration
    expires_at          TIMESTAMPTZ,
    
    -- Timestamps
    created_at          TIMESTAMPTZ   DEFAULT NOW(),
    updated_at          TIMESTAMPTZ   DEFAULT NOW(),
    
    -- Contrainte : 1 credential par plateforme par client
    CONSTRAINT uq_cred_client_platform UNIQUE (tenant_id, client_id, platform)
);

-- Index pour lookup rapide par client
CREATE INDEX idx_cred_client ON diffusion.credentials (client_id);

COMMENT ON TABLE diffusion.credentials IS 'Tokens OAuth des plateformes sociales (Facebook, Instagram, LinkedIn)';
COMMENT ON COLUMN diffusion.credentials.access_token IS 'Token en clair — sera chiffré en Phase 5 (pgcrypto ou application-level)';


-- ───────────────────────────────────────────────────
-- 3. TABLE: diffusion.channel_config
-- ───────────────────────────────────────────────────
-- Table de référence statique (6 lignes).
-- Définit les contraintes et paramètres de chaque canal.
-- ───────────────────────────────────────────────────

CREATE TABLE diffusion.channel_config (
    id                      SMALLSERIAL   PRIMARY KEY,
    
    -- Identifiant
    config_id               VARCHAR(50)   UNIQUE NOT NULL,
    channel_name            VARCHAR(20)   NOT NULL
                            CHECK (channel_name IN ('FACEBOOK', 'INSTAGRAM', 'LINKEDIN')),
    diffusion_type          VARCHAR(10)   NOT NULL
                            CHECK (diffusion_type IN ('ORGANIC', 'PAID')),
    post_type               VARCHAR(20),
    
    -- Limites de contenu (utilisé par l'AdaptationAgent pour les prompts LLM)
    text_max_chars          INTEGER,
    headline_max_chars      INTEGER,
    description_max_chars   INTEGER,
    hashtags_recommended    SMALLINT      DEFAULT 0,
    
    -- Flags
    media_required          BOOLEAN       DEFAULT FALSE,
    native_scheduling       BOOLEAN       DEFAULT FALSE,
    
    -- Paramètres LLM
    tone_default            VARCHAR(50),
    
    -- Estimation coût API
    typical_api_calls       SMALLINT      DEFAULT 1,
    tenant_id               BIGINT        NOT NULL,
    -- Unicité : 1 config par combinaison canal + type
    CONSTRAINT uq_config_channel_type UNIQUE (tenant_id, channel_name, diffusion_type)
);

COMMENT ON TABLE diffusion.channel_config IS 'Configuration de référence par canal et type de diffusion — utilisée pour la validation et les prompts LLM';


-- ───────────────────────────────────────────────────
-- 4. TABLE: diffusion.jobs
-- ───────────────────────────────────────────────────
-- Table centrale du système.
-- Chaque record = 1 job de diffusion sur 1 canal.
-- ───────────────────────────────────────────────────

CREATE TABLE diffusion.jobs (
    -- Clé technique
    id                  BIGSERIAL     PRIMARY KEY,
    
    -- Identifiants métier
    job_id              VARCHAR(50)   NOT NULL,
    request_id          VARCHAR(100)  NOT NULL,
    batch_id            VARCHAR(50)   NOT NULL,
    diffusion_id        BIGINT,
    
    -- Contexte source
    source_agent        VARCHAR(20)   NOT NULL
                        CHECK (source_agent IN (
                            'AGENT_ADS', 'AGENT_MAILING', 
                            'AGENT_COMMUNITY', 'IA_CRM'
                        )),
    tenant_id           BIGINT        NOT NULL,
    client_id           BIGINT        NOT NULL,
    campaign_id         BIGINT,
    
    -- Canal & Credentials
    channel_name        VARCHAR(20)   NOT NULL
                        CHECK (channel_name IN ('FACEBOOK', 'INSTAGRAM', 'LINKEDIN')),
    credential_ref      VARCHAR(50)   NOT NULL,
    diffusion_type      VARCHAR(10)   NOT NULL
                        CHECK (diffusion_type IN ('ORGANIC', 'PAID')),
    
    -- Stratégie
    funnel_stage        VARCHAR(10)
                        CHECK (funnel_stage IN ('TOFU', 'MOFU', 'BOFU')),
    scheduled_at        TIMESTAMPTZ,
    timezone            VARCHAR(50)   DEFAULT 'Africa/Casablanca',
    
    -- Budget (obligatoire pour PAID)
    budget_amount       NUMERIC(12,2),
    budget_currency     VARCHAR(5),
    
    -- Contenu (JSON variable selon le canal)
    payload             JSONB         NOT NULL DEFAULT '{}',
    
    -- Machine d'états (17 statuts possibles)
    status              VARCHAR(30)   NOT NULL DEFAULT 'RECEIVED'
                        CHECK (status IN (
                            'RECEIVED',
                            'SCHEDULED',
                            'REJECTED_SCHEMA',
                            'REJECTED_BUSINESS',
                            'DUPLICATE_IGNORED',
                            'ADAPTING',
                            'ADAPTED',
                            'REJECTED_PAYLOAD',
                            'FAILED_LLM',
                            'FAILED_ADAPTATION',
                            'PUBLISHING',
                            'PUBLISHED',
                            'FAILED_PRE_PUBLICATION',
                            'FAILED_CREDENTIALS',
                            'FAILED_PUBLICATION',
                            'PUBLICATION_DEFERRED',
                            'ORCHESTRATION_ERROR'
                        )),
    
    -- Retry
    retry_count         SMALLINT      DEFAULT 0,
    retry_max           SMALLINT      DEFAULT 3,
    
    -- Résultat publication
    platform_post_id    TEXT,
    last_error          JSONB,
    
    -- Timestamps
    created_at          TIMESTAMPTZ   DEFAULT NOW(),
    updated_at          TIMESTAMPTZ   DEFAULT NOW(),
    
    -- ─── Contraintes ───
    
    -- Unicité du job_id
    CONSTRAINT uq_jobs_job_id UNIQUE (tenant_id, job_id),
    
    -- Idempotence : même request_id + même canal = doublon
    CONSTRAINT uq_jobs_request_channel UNIQUE (tenant_id, request_id, channel_name),
    
    -- Budget obligatoire pour les diffusions PAID
    CONSTRAINT chk_budget_paid CHECK (
        (diffusion_type = 'PAID' AND budget_amount IS NOT NULL)
        OR
        (diffusion_type = 'ORGANIC')
    ),
    
    -- Intégrité référentielle vers credentials
    CONSTRAINT fk_jobs_credential FOREIGN KEY (credential_ref) 
        REFERENCES diffusion.credentials(credential_ref)
        ON UPDATE CASCADE
        ON DELETE RESTRICT  -- Empêche la suppression d'un credential utilisé
);

-- ─── Index de performance ───

-- Filtrage par status (Orchestrator : WHERE status = 'ADAPTED')
CREATE INDEX idx_jobs_status ON diffusion.jobs (status);

-- Regroupement par batch
CREATE INDEX idx_jobs_batch_id ON diffusion.jobs (batch_id);

-- Requêtes par client + canal
CREATE INDEX idx_jobs_tenant_client_chan ON diffusion.jobs (tenant_id, client_id, channel_name);

-- Tri chronologique (dashboards, monitoring)
CREATE INDEX idx_jobs_created ON diffusion.jobs (created_at);

-- Index partiel : uniquement les jobs planifiés (scheduler futur)
CREATE INDEX idx_jobs_scheduled ON diffusion.jobs (scheduled_at) 
    WHERE scheduled_at IS NOT NULL;

COMMENT ON TABLE diffusion.jobs IS 'Table centrale — chaque record représente un job de diffusion sur un canal spécifique';
COMMENT ON COLUMN diffusion.jobs.payload IS 'Contenu JSON variable selon le canal (texte, média, paramètres publicitaires)';
COMMENT ON COLUMN diffusion.jobs.last_error IS 'Dernière erreur en JSON structuré {error_code, error_message, details}';


-- ───────────────────────────────────────────────────
-- 5. TABLE: diffusion.log_events (PARTITIONNÉE)
-- ───────────────────────────────────────────────────
-- Table de volume élevé (5-8 logs par job).
-- Partitionnée par mois pour :
--   - Performance : chaque partition a ses propres index
--   - Maintenance : DROP partition au lieu de DELETE (1ms vs heures)
--   - Rétention : 6 mois actifs, archivage automatique
-- ───────────────────────────────────────────────────

CREATE TABLE diffusion.log_events (
    id                  BIGSERIAL,
    log_id              VARCHAR(50)   NOT NULL,
    job_id              VARCHAR(50),
    correlation_id      VARCHAR(50),
    agent               VARCHAR(30)   NOT NULL,
    event_type          VARCHAR(50)   NOT NULL,
    message             TEXT,
    tenant_id           BIGINT        NOT NULL,
    timestamp           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    
    -- PK composite obligatoire pour les tables partitionnées
    -- (la clé de partition doit faire partie de la PK)
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

-- ─── Index ───
CREATE INDEX idx_logs_job_id      ON diffusion.log_events (job_id);
CREATE INDEX idx_logs_correlation ON diffusion.log_events (correlation_id);
CREATE INDEX idx_logs_agent_event ON diffusion.log_events (agent, event_type);
CREATE INDEX idx_logs_timestamp   ON diffusion.log_events (timestamp);

-- ─── Partitions initiales (Mars → Août 2026 = 6 mois) ───
CREATE TABLE diffusion.log_events_2026_03 PARTITION OF diffusion.log_events
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE diffusion.log_events_2026_04 PARTITION OF diffusion.log_events
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE diffusion.log_events_2026_05 PARTITION OF diffusion.log_events
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE TABLE diffusion.log_events_2026_06 PARTITION OF diffusion.log_events
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE TABLE diffusion.log_events_2026_07 PARTITION OF diffusion.log_events
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

CREATE TABLE diffusion.log_events_2026_08 PARTITION OF diffusion.log_events
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

COMMENT ON TABLE diffusion.log_events IS 'Logs du système — partitionnée par mois, rétention 6 mois';


-- ───────────────────────────────────────────────────
-- 6. TRIGGERS
-- ───────────────────────────────────────────────────

-- Fonction réutilisable : mise à jour automatique de updated_at
CREATE OR REPLACE FUNCTION diffusion.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger sur jobs
CREATE TRIGGER trg_jobs_updated
    BEFORE UPDATE ON diffusion.jobs
    FOR EACH ROW
    EXECUTE FUNCTION diffusion.update_timestamp();

-- Trigger sur credentials
CREATE TRIGGER trg_credentials_updated
    BEFORE UPDATE ON diffusion.credentials
    FOR EACH ROW
    EXECUTE FUNCTION diffusion.update_timestamp();


-- ───────────────────────────────────────────────────
-- 7. FONCTIONS UTILITAIRES
-- ───────────────────────────────────────────────────

-- Création automatique de la partition du mois suivant
-- À exécuter via cron le 25 de chaque mois
CREATE OR REPLACE FUNCTION diffusion.create_next_monthly_partition()
RETURNS TEXT AS $$
DECLARE
    partition_date  DATE := DATE_TRUNC('month', NOW() + INTERVAL '1 month');
    partition_name  TEXT;
    start_date      TEXT;
    end_date        TEXT;
BEGIN
    partition_name := 'log_events_' || TO_CHAR(partition_date, 'YYYY_MM');
    start_date     := TO_CHAR(partition_date, 'YYYY-MM-DD');
    end_date       := TO_CHAR(partition_date + INTERVAL '1 month', 'YYYY-MM-DD');
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'diffusion' 
        AND tablename = partition_name
    ) THEN
        EXECUTE format(
            'CREATE TABLE diffusion.%I PARTITION OF diffusion.log_events FOR VALUES FROM (%L) TO (%L)',
            partition_name, start_date, end_date
        );
        RETURN 'Partition créée : diffusion.' || partition_name;
    ELSE
        RETURN 'Partition existe déjà : diffusion.' || partition_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Nettoyage des partitions de plus de 6 mois
-- À exécuter via cron le 1er de chaque mois
CREATE OR REPLACE FUNCTION diffusion.cleanup_old_partitions(retention_months INTEGER DEFAULT 6)
RETURNS TEXT AS $$
DECLARE
    cutoff_date     DATE := DATE_TRUNC('month', NOW() - (retention_months || ' months')::INTERVAL);
    partition_name  TEXT;
    dropped         TEXT := '';
    rec             RECORD;
BEGIN
    FOR rec IN
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'diffusion' 
        AND tablename LIKE 'log_events_%'
        AND tablename != 'log_events'
        ORDER BY tablename
    LOOP
        -- Extraire la date de la partition (format: log_events_YYYY_MM)
        DECLARE
            year_part   INTEGER;
            month_part  INTEGER;
            part_date   DATE;
        BEGIN
            year_part  := SUBSTRING(rec.tablename FROM 'log_events_(\d{4})_')::INTEGER;
            month_part := SUBSTRING(rec.tablename FROM 'log_events_\d{4}_(\d{2})')::INTEGER;
            part_date  := MAKE_DATE(year_part, month_part, 1);
            
            IF part_date < cutoff_date THEN
                EXECUTE format('DROP TABLE diffusion.%I', rec.tablename);
                dropped := dropped || rec.tablename || ', ';
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- Skip les noms qui ne matchent pas le pattern
            CONTINUE;
        END;
    END LOOP;
    
    IF dropped = '' THEN
        RETURN 'Aucune partition à supprimer (rétention: ' || retention_months || ' mois)';
    ELSE
        RETURN 'Partitions supprimées : ' || LEFT(dropped, LENGTH(dropped) - 2);
    END IF;
END;
$$ LANGUAGE plpgsql;


-- ───────────────────────────────────────────────────
-- 8. VUES
-- ───────────────────────────────────────────────────

-- Dashboard temps réel : état du système
CREATE VIEW diffusion.v_jobs_dashboard AS
SELECT 
    status,
    channel_name,
    diffusion_type,
    COUNT(*)                                                          AS total_jobs,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '1 hour')   AS last_hour,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours') AS last_24h,
    ROUND(AVG(EXTRACT(EPOCH FROM (updated_at - created_at)))::NUMERIC, 1) AS avg_duration_sec
FROM diffusion.jobs
GROUP BY status, channel_name, diffusion_type
ORDER BY total_jobs DESC;

-- Vue : jobs en échec nécessitant attention
CREATE VIEW diffusion.v_failed_jobs AS
SELECT 
    job_id,
    channel_name,
    diffusion_type,
    status,
    retry_count,
    retry_max,
    last_error->>'error_code' AS error_code,
    last_error->>'error_message' AS error_message,
    created_at,
    updated_at
FROM diffusion.jobs
WHERE status IN (
    'FAILED_LLM', 'FAILED_ADAPTATION', 
    'FAILED_PRE_PUBLICATION', 'FAILED_CREDENTIALS', 
    'FAILED_PUBLICATION', 'ORCHESTRATION_ERROR'
)
ORDER BY updated_at DESC;

-- Vue : credentials expirant bientôt (< 7 jours)
CREATE VIEW diffusion.v_expiring_credentials AS
SELECT 
    credential_ref,
    client_id,
    platform,
    expires_at,
    EXTRACT(EPOCH FROM (expires_at - NOW())) / 3600 AS hours_remaining
FROM diffusion.credentials
WHERE expires_at IS NOT NULL
AND expires_at < NOW() + INTERVAL '7 days'
ORDER BY expires_at ASC;

-- Vue : taille des partitions de logs
CREATE VIEW diffusion.v_log_partitions AS
SELECT 
    child.relname                         AS partition_name,
    pg_size_pretty(pg_total_relation_size(child.oid)) AS total_size,
    pg_stat_get_live_tuples(child.oid)    AS row_count
FROM pg_inherits
JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
JOIN pg_class child  ON pg_inherits.inhrelid  = child.oid
JOIN pg_namespace ns ON parent.relnamespace   = ns.oid
WHERE ns.nspname = 'diffusion' 
AND parent.relname = 'log_events'
ORDER BY child.relname;

COMMENT ON VIEW diffusion.v_jobs_dashboard IS 'Dashboard temps réel — état du système par status/canal/type';
COMMENT ON VIEW diffusion.v_failed_jobs IS 'Jobs en échec nécessitant intervention';
COMMENT ON VIEW diffusion.v_expiring_credentials IS 'Credentials OAuth expirant dans les 7 prochains jours';
COMMENT ON VIEW diffusion.v_log_partitions IS 'Taille et nombre de lignes par partition de logs';


-- ───────────────────────────────────────────────────
-- 9. DONNÉES INITIALES (SEED)
-- ───────────────────────────────────────────────────

-- Channel Config — 6 configurations (3 canaux × 2 types)
INSERT INTO diffusion.channel_config
(config_id, channel_name, diffusion_type, post_type,
 text_max_chars, headline_max_chars, description_max_chars,
 hashtags_recommended, media_required, native_scheduling,
 tone_default, typical_api_calls, tenant_id) -- 👈 AJOUT DE LA COLONNE ICI
VALUES
    ('FACEBOOK_ORGANIC',  'FACEBOOK',  'ORGANIC', 'FEED',
     63206, NULL, NULL, 3,  FALSE, TRUE,  'conversationnel', 1, 1), -- 👈 AJOUT DU TENANT_ID (1)

    ('FACEBOOK_PAID',     'FACEBOOK',  'PAID',    'SINGLE_IMAGE',
     63206, 40,   30,   0,  TRUE,  TRUE,  'persuasif',       4, 1),

    ('INSTAGRAM_ORGANIC', 'INSTAGRAM', 'ORGANIC', 'FEED',
     2200,  NULL, NULL, 15, TRUE,  FALSE, 'visuel',          2, 1),

    ('INSTAGRAM_PAID',    'INSTAGRAM', 'PAID',    'STORY',
     2200,  NULL, NULL, 5,  TRUE,  FALSE, 'accrocheur',      4, 1),

    ('LINKEDIN_ORGANIC',  'LINKEDIN',  'ORGANIC', 'DEFAULT',
     3000,  NULL, NULL, 5,  FALSE, FALSE, 'professionnel',   2, 1),

    ('LINKEDIN_PAID',     'LINKEDIN',  'PAID',    'SINGLE_IMAGE',
     600,   70,   200,  0,  TRUE,  TRUE,  'professionnel',   3, 1);


COMMIT;

-- ═══════════════════════════════════════════════════════════════════
-- Vérification post-installation
-- ═══════════════════════════════════════════════════════════════════

-- Vérifier que tout est créé
SELECT 'Tables créées:' AS info;
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname = 'diffusion' 
ORDER BY tablename;

SELECT 'Seed channel_config:' AS info;
SELECT config_id, channel_name, diffusion_type, text_max_chars 
FROM diffusion.channel_config;

SELECT 'Partitions log_events:' AS info;
SELECT * FROM diffusion.v_log_partitions;
