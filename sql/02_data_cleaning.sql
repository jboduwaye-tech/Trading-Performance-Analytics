-- Data Source: trades_raw.csv (Tradovate export)
-- Ingestion Method: Imported into MySQL using MySQL Workbench Import Wizard
-- Pipeline Stage: Data Cleaning & Transformation
-- Output: trades_clean (analysis-ready dataset)
-- Key Transformations:
--   - Converted string-based datetime to MySQL DATETIME
--   - Normalized PnL values (handled bracketed negatives)
--   - Standardized numeric fields for analysis
--   - Converted trade duration to numeric seconds for analytical use
--   - Enforced consistent schema (data types, naming conventions)

USE trading_analysis;

-- Step 1: Create the cleaned trades table with appropriate data types and structure
CREATE TABLE trades_clean (
    trade_id INT AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(10),
    contract_size INT,
    buy_price DECIMAL(10,5),
    buy_time DATETIME,
    sell_price DECIMAL(10,5),
    sell_time DATETIME,
    pnl DECIMAL(10,2),
    trade_duration_seconds INT UNSIGNED
);

-- Step 2: Insert transformed data from the raw trades table into the cleaned trades table
INSERT INTO trades_clean (
    symbol,
    contract_size,
    buy_price,
    buy_time,
    sell_price,
    sell_time,
    pnl,
    trade_duration_seconds
)
SELECT
    symbol,
    CAST(qty AS UNSIGNED) AS contract_size,
    CAST(buy_price AS DECIMAL(10,5)),
    STR_TO_DATE(buy_time, '%m/%d/%Y %H:%i:%s'),
    CAST(sell_price AS DECIMAL(10,5)),
    STR_TO_DATE(sell_time, '%m/%d/%Y %H:%i:%s'),
    
    CASE
        WHEN pnl LIKE '(%' OR pnl LIKE '$(%' THEN
            -CAST(
                REPLACE(REPLACE(REPLACE(REPLACE(pnl, '$',''),'(',''),')',''),',','')
            AS DECIMAL(10,2))
        ELSE
            CAST(REPLACE(REPLACE(pnl,'$',''),',','') AS DECIMAL(10,2))
    END,

    ABS(
        TIMESTAMPDIFF(
            SECOND,
            STR_TO_DATE(buy_time, '%m/%d/%Y %H:%i:%s'),
            STR_TO_DATE(sell_time, '%m/%d/%Y %H:%i:%s')
        )
    )
    

FROM trades_raw;
