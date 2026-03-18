-- Data Source: trades.csv (exported from Tradovate futures trading platform)
-- Pipeline Stage: Raw Data Ingestion / Staging Layer
-- Description:
--   Stores raw trading data imported directly from the source CSV file.
--   Columns are defined as VARCHAR to preserve original formatting and prevent
--   ingestion errors due to inconsistent data types.
--   Serves as the staging table for downstream data cleaning and transformation
--   into an analysis-ready dataset.
-- Note:
--   No transformations are applied at this stage. All data cleaning,
--   type casting, and normalization are handled in subsequent pipeline steps.

USE trading_analysis;

CREATE TABLE trades_raw (
    trade_id INT AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(10),
    price_format VARCHAR(20),
    price_format_type VARCHAR(20),
    tick_size VARCHAR(20),
    buyfill_id VARCHAR(30),
    sellfill_id VARCHAR(30),
    qty VARCHAR(20),
    buy_price VARCHAR(20),
    buy_time VARCHAR(30),
    sell_price VARCHAR(20),
    sell_time VARCHAR(30),
    pnl VARCHAR(20),
    duration VARCHAR(30)
);