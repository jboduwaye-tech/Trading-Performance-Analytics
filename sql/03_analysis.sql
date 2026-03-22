-- =================================================================
-- Trading Performance Analysis
-- Dataset: trades_clean
-- Author: Joseph Oduwaye
-- Description: End-to-end analysis of trading performance 
-- including expectancy, win/loss structure, and behavioral patterns.
-- =================================================================

-- NOTE:
-- Dataset contains a limited number of trades (n=10).
-- Insights are illustrative and demonstrate analytical methodology
-- rather than statistically significant conclusions.

/*
============================================================
1. OVERALL PERFORMANCE SUMMARY
Purpose:
Establish baseline performance metrics across all trades
============================================================
*/

USE trading_analysis;
SELECT
    COUNT(*) AS total_trades,
    SUM(pnl) AS total_pnl,
    AVG(pnl) AS avg_pnl_per_trade,  -- direct expectancy
    MIN(pnl) AS worst_trade,
    MAX(pnl) AS best_trade

FROM trades_clean;

/*
============================================================
2. EXPECTANCY DECOMPOSITION
Purpose:
Break down profitability into win rate and payoff structure
============================================================
*/

SELECT
    COUNT(*) AS total_trades,

    -- Win / Loss Counts
    SUM(CASE WHEN pnl > 0 THEN 1 ELSE 0 END) AS winning_trades,
    SUM(CASE WHEN pnl < 0 THEN 1 ELSE 0 END) AS losing_trades,

    -- Win / Loss Rates
    SUM(CASE WHEN pnl > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS win_rate,
    SUM(CASE WHEN pnl < 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS loss_rate,

    -- Average Win / Loss
    AVG(CASE WHEN pnl > 0 THEN pnl END) AS avg_win,
    AVG(CASE WHEN pnl < 0 THEN pnl END) AS avg_loss,

    -- Profit Factor
    SUM(CASE WHEN pnl > 0 THEN pnl END) /
ABS(SUM(CASE WHEN pnl < 0 THEN pnl END)) AS profit_factor,

    -- Expectancy (direct)
    AVG(pnl) AS avg_pnl_per_trade,

    -- Expectancy (decomposed)
    (
        (SUM(CASE WHEN pnl > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*)) *
        AVG(CASE WHEN pnl > 0 THEN pnl END)
    )
    -
    (
        (SUM(CASE WHEN pnl < 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*)) *
        ABS(AVG(CASE WHEN pnl < 0 THEN pnl END))
    ) AS expectancy_calc

FROM trades_clean;

/*
============================================================
3. TRADE DURATION ANALYSIS
Purpose:
Analyze relationship between holding time and performance
============================================================
*/

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
GROUP BY duration_bucket
ORDER BY total_trades DESC;

/*
===============================================================
4. TIME-BASED PERFORMANCE
Purpose:
- Identify intraday edge based on entry timing 
- Entry time derived as earliest timestamp between buy and sell
to normalize long and short trades into a consistent framework
===============================================================
*/

SELECT
    EXTRACT(HOUR FROM LEAST(buy_time, sell_time)) AS trade_hour,

    COUNT(*) AS total_trades,
    AVG(pnl) AS avg_pnl,
    SUM(pnl) AS total_pnl

FROM trades_clean
GROUP BY trade_hour
ORDER BY trade_hour;

/*
============================================================
5. STREAK ANALYSIS
Purpose:
Evaluate performance following wins and losses
============================================================
*/

WITH trades_outcomes AS (
    SELECT
        *,
        CASE WHEN pnl > 0 THEN 1 ELSE 0 END AS is_win
    FROM trades_clean
),

trades_enriched AS (
    SELECT 
        *,
        LEAST(buy_time, sell_time) AS entry_time,
        GREATEST(buy_time, sell_time) AS exit_time
    FROM trades_outcomes
    ),

streaks AS (
    SELECT
        *,
        LAG(is_win) OVER (ORDER BY entry_time, trade_id) AS prev_trade_result
    FROM trades_enriched
)

SELECT
    CASE 
        WHEN prev_trade_result = 1 THEN 'Previous Win'
        WHEN prev_trade_result = 0 THEN 'Previous Loss'
    END AS prev_trade_label,

    COUNT(*) AS total_trades,
    AVG(pnl) AS avg_pnl_after_state,
    AVG(is_win) AS win_rate_after_state

FROM streaks
WHERE prev_trade_result IS NOT NULL
GROUP BY prev_trade_result;

/*
============================================================
6. EQUITY CURVE / DRAWDOWN ANALYSIS
Purpose:
Evaluate performance growth and risk through cumulative P&L 
and drawdown metrics
============================================================
*/

WITH trades_enriched AS (
    SELECT
        *,
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
FROM drawdown_calc
ORDER BY entry_time;
