-- TurnaroundChecklist KPI Schema
-- Data Layer for Analytics & Power BI Integration
-- BCN | 2026

-- ============================================================
-- CORE TURNAROUND TABLE
-- ============================================================

CREATE TABLE turnarounds (
    turnaround_id          UUID PRIMARY KEY,
    contract_address       VARCHAR(42) NOT NULL,         -- Ethereum/Camino contract address
    off_chain_id           VARCHAR(100) NOT NULL UNIQUE, -- Human-readable ID (e.g., BCN-VY8123-2026-01-09)
    airport_code           VARCHAR(3) NOT NULL,          -- IATA code (BCN, MAD, etc.)
    flight_number          VARCHAR(10),                  -- Optional flight ID
    airline_code           VARCHAR(3),                   -- IATA airline code
    scheduled_arrival      TIMESTAMP NOT NULL,
    scheduled_departure    TIMESTAMP NOT NULL,
    actual_departure       TIMESTAMP,                    -- NULL if not certified
    is_certified           BOOLEAN DEFAULT FALSE,
    certification_hash     VARCHAR(66),                  -- Cryptographic hash from blockchain
    certification_time     TIMESTAMP,
    created_at             TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- TASK EXECUTION TABLE
-- ============================================================

CREATE TABLE task_executions (
    execution_id           UUID PRIMARY KEY,
    turnaround_id          UUID REFERENCES turnarounds(turnaround_id),
    task_id                INT NOT NULL,                 -- Task ID (0-26)
    task_name              VARCHAR(100),                 -- Human-readable task name
    assigned_actor         VARCHAR(20) NOT NULL,         -- Actor enum (GroundHandling, Cleaning, etc.)
    actor_wallet           VARCHAR(42),                  -- Wallet address that executed task
    deadline               TIMESTAMP NOT NULL,
    completed_at           TIMESTAMP,
    status                 VARCHAR(10) NOT NULL,         -- Pending / OnTime / Late
    is_mandatory           BOOLEAN DEFAULT TRUE,
    justification          TEXT,                         -- Delay justification (if late)
    blockchain_tx_hash     VARCHAR(66),                  -- Transaction hash from blockchain event
    created_at             TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- ACTOR PERFORMANCE TABLE
-- ============================================================

CREATE TABLE actor_performance (
    performance_id         UUID PRIMARY KEY,
    turnaround_id          UUID REFERENCES turnarounds(turnaround_id),
    actor                  VARCHAR(20) NOT NULL,
    wallet_address         VARCHAR(42),
    tasks_assigned         INT NOT NULL DEFAULT 0,
    tasks_completed        INT NOT NULL DEFAULT 0,
    tasks_on_time          INT NOT NULL DEFAULT 0,
    tasks_late             INT NOT NULL DEFAULT 0,
    tasks_justified        INT NOT NULL DEFAULT 0,
    badge_earned           BOOLEAN DEFAULT FALSE,
    badge_token_id         INT,                          -- NFT token ID (if badge minted)
    created_at             TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- KPI SUMMARY TABLE (FOR REPORTING)
-- ============================================================

CREATE TABLE turnaround_kpis (
    kpi_id                 UUID PRIMARY KEY,
    turnaround_id          UUID REFERENCES turnarounds(turnaround_id),
    total_tasks            INT NOT NULL DEFAULT 27,
    mandatory_tasks        INT NOT NULL,
    tasks_completed        INT NOT NULL DEFAULT 0,
    tasks_on_time          INT NOT NULL DEFAULT 0,
    tasks_late             INT NOT NULL DEFAULT 0,
    tasks_unjustified_late INT NOT NULL DEFAULT 0,       -- KPI: late tasks without justification
    sla_breached           BOOLEAN DEFAULT FALSE,
    operational_duration_min INT,                        -- Actual duration in minutes
    certification_time     TIMESTAMP,
    created_at             TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- BADGE ISSUANCE TABLE
-- ============================================================

CREATE TABLE badges (
    badge_id               UUID PRIMARY KEY,
    turnaround_id          UUID REFERENCES turnarounds(turnaround_id),
    actor                  VARCHAR(20) NOT NULL,
    wallet_address         VARCHAR(42) NOT NULL,
    token_id               INT NOT NULL UNIQUE,          -- ERC-721 token ID
    contract_address       VARCHAR(42) NOT NULL,         -- Badge NFT contract
    ipfs_metadata_uri      TEXT,                         -- IPFS metadata URI
    minted_at              TIMESTAMP NOT NULL,
    blockchain_tx_hash     VARCHAR(66),
    created_at             TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- VIEWS FOR POWER BI / TABLEAU
-- ============================================================

-- View: Turnaround summary with KPIs
CREATE OR REPLACE VIEW vw_turnaround_summary AS
SELECT
    t.turnaround_id,
    t.off_chain_id,
    t.airport_code,
    t.flight_number,
    t.airline_code,
    t.scheduled_arrival,
    t.scheduled_departure,
    t.actual_departure,
    t.is_certified,
    k.total_tasks,
    k.tasks_on_time,
    k.tasks_late,
    k.tasks_unjustified_late,
    k.sla_breached,
    k.operational_duration_min,
    CASE
        WHEN k.sla_breached THEN 'Breached'
        ELSE 'Compliant'
    END AS sla_status,
    ROUND((k.tasks_on_time::NUMERIC / k.total_tasks) * 100, 2) AS on_time_percentage
FROM turnarounds t
LEFT JOIN turnaround_kpis k ON t.turnaround_id = k.turnaround_id;

-- View: Actor performance aggregation
CREATE OR REPLACE VIEW vw_actor_performance AS
SELECT
    actor,
    wallet_address,
    COUNT(DISTINCT turnaround_id) AS turnarounds_participated,
    SUM(tasks_completed) AS total_tasks_completed,
    SUM(tasks_on_time) AS total_tasks_on_time,
    SUM(tasks_late) AS total_tasks_late,
    SUM(tasks_justified) AS total_tasks_justified,
    SUM(CASE WHEN badge_earned THEN 1 ELSE 0 END) AS total_badges_earned,
    ROUND((SUM(tasks_on_time)::NUMERIC / SUM(tasks_completed)) * 100, 2) AS on_time_rate
FROM actor_performance
GROUP BY actor, wallet_address;

-- View: Airport performance (aggregated by airport)
CREATE OR REPLACE VIEW vw_airport_performance AS
SELECT
    t.airport_code,
    COUNT(DISTINCT t.turnaround_id) AS total_turnarounds,
    SUM(CASE WHEN k.sla_breached THEN 1 ELSE 0 END) AS total_sla_breached,
    AVG(k.operational_duration_min) AS avg_operational_duration_min,
    AVG((k.tasks_on_time::NUMERIC / k.total_tasks) * 100) AS avg_on_time_percentage
FROM turnarounds t
LEFT JOIN turnaround_kpis k ON t.turnaround_id = k.turnaround_id
WHERE t.is_certified = TRUE
GROUP BY t.airport_code;

-- ============================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================

CREATE INDEX idx_turnarounds_airport ON turnarounds(airport_code);
CREATE INDEX idx_turnarounds_certified ON turnarounds(is_certified);
CREATE INDEX idx_turnarounds_scheduled_arrival ON turnarounds(scheduled_arrival);
CREATE INDEX idx_task_executions_turnaround ON task_executions(turnaround_id);
CREATE INDEX idx_task_executions_actor ON task_executions(assigned_actor);
CREATE INDEX idx_task_executions_status ON task_executions(status);
CREATE INDEX idx_actor_performance_actor ON actor_performance(actor);
CREATE INDEX idx_badges_turnaround ON badges(turnaround_id);
CREATE INDEX idx_badges_actor ON badges(actor);

-- ============================================================
-- COMMENTS
-- ============================================================

COMMENT ON TABLE turnarounds IS 'Core turnaround data from blockchain smart contracts';
COMMENT ON TABLE task_executions IS 'Individual task completion events';
COMMENT ON TABLE actor_performance IS 'Performance metrics per actor per turnaround';
COMMENT ON TABLE turnaround_kpis IS 'Aggregated KPI metrics for reporting';
COMMENT ON TABLE badges IS 'TurnaroundBadge NFT issuance records';

COMMENT ON COLUMN turnarounds.certification_hash IS 'Immutable cryptographic hash from smart contract';
COMMENT ON COLUMN task_executions.blockchain_tx_hash IS 'Transaction hash from TaskCompleted event';
COMMENT ON COLUMN actor_performance.badge_earned IS 'Whether actor earned NFT badge for this turnaround';

-- ============================================================
-- TurnaroundChecklist Data Layer v0.1 | Barcelona 2026
-- ============================================================
