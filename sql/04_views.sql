-- ================================================================
-- VIEWS FOR DOWNSTREAM VISUALIZATION
-- Project: Trading Performance Analysis
-- Author: Joseph
--
-- Description:
-- This file defines reusable SQL views designed for BI tools
-- (Power BI / Python). Each view represents a clean, aggregated
-- dataset aligned to a specific analytical question.
--
-- Note:
-- Dataset is small (n=10), metrics are illustrative and designed
-- to demonstrate analytical methodology.
-- ================================================================

USE trading_analysis;
-- 1. vw_trades_enriched
-- Base dataset with engineered features used across all analyses
-- (entry_time, trade_hour, win/loss classification)
CREATE OR REPLACE VIEW vw_trades_enriched AS
SELECT
    trade_id,
    pnl,
    trade_duration_seconds,

    LEAST(buy_time, sell_time) AS entry_time,
    GREATEST(buy_time, sell_time) AS exit_time,

    EXTRACT(HOUR FROM LEAST(buy_time, sell_time)) AS trade_hour,

    CASE WHEN pnl > 0 THEN 1 ELSE 0 END AS is_win,

    CASE
        WHEN trade_duration_seconds < 60 THEN 'Under 1 min'
        WHEN trade_duration_seconds < 900 THEN '1–15 min'
        WHEN trade_duration_seconds < 3600 THEN '15–60 min'
        ELSE '60+ min'
    END AS duration_bucket

FROM trades_clean;

-- 2. vw_expectancy_breakdown
-- Core profitability metrics: expectancy, win rate, payoff structure
-- Used for KPI cards and high-level performance evaluation
CREATE OR REPLACE VIEW vw_expectancy_breakdown AS
SELECT
    COUNT(*) AS total_trades,

    AVG(pnl) AS expectancy,

    AVG(CASE WHEN pnl > 0 THEN pnl END) AS avg_win,
    AVG(CASE WHEN pnl < 0 THEN pnl END) AS avg_loss,

    SUM(CASE WHEN pnl > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS win_rate,

    SUM(CASE WHEN pnl > 0 THEN pnl END) /
    NULLIF(ABS(SUM(CASE WHEN pnl < 0 THEN pnl END)), 0) AS profit_factor

FROM trades_clean;

-- 3. vw_time_performance
-- Intraday performance by trade entry hour
-- Used to identify time-based trading edges and optimize trade timing
CREATE OR REPLACE VIEW vw_time_performance AS
SELECT
    EXTRACT(HOUR FROM LEAST(buy_time, sell_time)) AS trade_hour,
    COUNT(*) AS total_trades,
    AVG(pnl) AS avg_pnl,
    SUM(pnl) AS total_pnl
FROM trades_clean
GROUP BY trade_hour;

-- 4. vw_duration_performance
-- Performance segmented by trade holding duration
-- Helps identify optimal trade holding periods
CREATE OR REPLACE VIEW vw_duration_performance AS
SELECT
    CASE
        WHEN trade_duration_seconds < 60 THEN 'Under 1 min'
        WHEN trade_duration_seconds < 900 THEN '1–15 min'
        WHEN trade_duration_seconds < 3600 THEN '15–60 min'
        ELSE '60+ min'
    END AS duration_bucket,

    COUNT(*) AS total_trades,
    AVG(pnl) AS avg_pnl,
    SUM(pnl) AS total_pnl

FROM trades_clean
GROUP BY duration_bucket;

-- 5. vw_streak_performance
-- Conditional performance based on previous trade outcome
-- Used to detect behavioral patterns (overconfidence, revenge trading)
CREATE OR REPLACE VIEW vw_streak_performance AS
WITH base AS (
    SELECT
        *,
        CASE WHEN pnl > 0 THEN 1 ELSE 0 END AS is_win,
        LEAST(buy_time, sell_time) AS entry_time
    FROM trades_clean
),
lagged AS (
    SELECT
        *,
        LAG(is_win) OVER (ORDER BY entry_time, trade_id) AS prev_trade_result
    FROM base
)
SELECT
    prev_trade_result,
    COUNT(*) AS total_trades,
    AVG(pnl) AS avg_pnl_after_state,
    AVG(is_win) AS win_rate_after_state
FROM lagged
WHERE prev_trade_result IS NOT NULL
GROUP BY prev_trade_result;

-- 6. vw_equity_drawdown
-- Time-series view of cumulative PnL and drawdown
-- Used to evaluate performance consistency and risk exposure
CREATE OR REPLACE VIEW vw_equity_drawdown AS
WITH trades_enriched AS (
    SELECT
        trade_id,
        pnl,
        LEAST(buy_time, sell_time) AS entry_time
    FROM trades_clean
),

equity_curve AS (
    SELECT
        *,
        SUM(pnl) OVER (ORDER BY entry_time, trade_id) AS cumulative_pnl
    FROM trades_enriched
),

drawdown_calc AS (
    SELECT
        *,
        MAX(cumulative_pnl) OVER (ORDER BY entry_time, trade_id) AS running_peak,
        cumulative_pnl - MAX(cumulative_pnl) OVER (ORDER BY entry_time, trade_id) AS drawdown
    FROM equity_curve
)

SELECT
    entry_time,
    pnl,
    cumulative_pnl,
    running_peak,
    drawdown
FROM drawdown_calc;
