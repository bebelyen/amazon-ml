-- Household Size Prediction: Feature Engineering in SQL

-- Reproduce the feature engineering pipeline using SQL.
--
-- Assumes two tables:
--   purchases       (survey_response_id, order_date, purchase_price_per_unit,
--                    quantity, title, asin, category, shipping_address_state)
--   survey          (survey_response_id, hh_size, amazon_use_frequency,
--                    income, test)

-- 1. Basic Behavioral Aggregates Per User
-- Captures overall purchasing scale, diversity, and price range.
-- These are the first signals that purchasing volume correlates
-- with household size.

CREATE TABLE user_aggregates AS
SELECT
    survey_response_id,

    -- Volume features
    COUNT(*) AS n_orders,
    SUM(quantity) AS total_quantity,
    SUM(purchase_price_per_unit * quantity) AS total_spend,

    -- Price features
    AVG(purchase_price_per_unit) AS mean_price,
    MAX(purchase_price_per_unit) AS max_price,
    MIN(purchase_price_per_unit) AS min_price,

    -- Diversity features
    COUNT(DISTINCT shipping_address_state) AS n_unique_states,
    COUNT(DISTINCT title) AS n_unique_titles,
    COUNT(DISTINCT asin) AS n_unique_asins,
    COUNT(DISTINCT category) AS n_unique_categories,

    -- Date range (used for recency features below)
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date

FROM purchases
GROUP BY survey_response_id;

-- 2. Recency and Duration Features

CREATE TABLE user_features AS
SELECT
    u.*,

    -- Days between first and last order
    DATEDIFF(last_order_date, first_order_date) AS days_active,

    -- Days since most recent order (relative to latest date in dataset)
    DATEDIFF(
        (SELECT MAX(order_date) FROM purchases),
        last_order_date
    ) AS days_since_last_order,

    -- Per-order averages
    SUM(purchase_price_per_unit * quantity)
        / NULLIF(COUNT(*), 0) AS spend_per_order,
    SUM(quantity)
        / NULLIF(COUNT(*), 0) AS qty_per_order

FROM user_aggregates u;


-- 3. Household Item Flag

CREATE TABLE household_item_counts AS
SELECT
    survey_response_id,
    COUNT(*) AS n_household_items
FROM purchases
WHERE UPPER(category) REGEXP
    'TOILET|PAPER|TOWEL|NAPKIN|CLEAN|SOAP|LAUNDRY|GROCERY|FOOD|DRINK|WATER'
GROUP BY survey_response_id;

-- 4. Kid / Baby Item Flag

CREATE TABLE kid_item_counts AS
SELECT
    survey_response_id,
    COUNT(*) AS n_kid_items
FROM purchases
WHERE UPPER(category) REGEXP
    'DIAPER|WIPE|BABY|INFANT|TODDLER|TOY|STROLLER|BOTTLE|PACIFIER|CRIB|KIDS|CHILD|CHILDREN'
GROUP BY survey_response_id;

-- 5. Final Feature Table (joins all features + survey labels)

CREATE TABLE model_dataset AS
SELECT
    s.survey_response_id,
    s.hh_size AS target,
    s.test,

    -- Behavioral aggregates
    COALESCE(f.n_orders, 0) AS n_orders,
    COALESCE(f.total_quantity, 0) AS total_quantity,
    COALESCE(f.total_spend, 0) AS total_spend,
    COALESCE(f.mean_price, 0) AS mean_price,
    COALESCE(f.max_price, 0) AS max_price,
    COALESCE(f.min_price, 0) AS min_price,
    COALESCE(f.n_unique_states, 0) AS n_unique_states,
    COALESCE(f.n_unique_titles, 0) AS n_unique_titles,
    COALESCE(f.n_unique_asins, 0) AS n_unique_asins,
    COALESCE(f.n_unique_categories, 0) AS n_unique_categories,

    -- Recency and duration
    COALESCE(f.days_active, 0) AS days_active,
    COALESCE(f.days_since_last_order, 0) AS days_since_last_order,
    COALESCE(f.spend_per_order, 0) AS spend_per_order,
    COALESCE(f.qty_per_order, 0) AS qty_per_order,

    -- Domain-specific flags
    COALESCE(h.n_household_items, 0) AS n_household_items,
    COALESCE(k.n_kid_items, 0) AS n_kid_items

FROM survey s
LEFT JOIN user_features f
    ON s.survey_response_id = f.survey_response_id
LEFT JOIN household_item_counts h
    ON s.survey_response_id = h.survey_response_id
LEFT JOIN kid_item_counts k
    ON s.survey_response_id = k.survey_response_id;


-- 6. Exploratory Queries


-- Average household size by income bracket
SELECT
    s.income,
    ROUND(AVG(s.hh_size), 2) AS avg_hh_size,
    COUNT(*) AS n_users
FROM survey s
WHERE s.income IS NOT NULL
GROUP BY s.income
ORDER BY avg_hh_size DESC;


-- Average spend by household size — do larger households spend more?
SELECT
    s.hh_size,
    ROUND(AVG(f.total_spend), 2) AS avg_total_spend,
    ROUND(AVG(f.n_orders), 2) AS avg_n_orders,
    COUNT(*) AS n_users
FROM survey s
LEFT JOIN user_features f
    ON s.survey_response_id = f.survey_response_id
WHERE s.hh_size IS NOT NULL
GROUP BY s.hh_size
ORDER BY s.hh_size;


-- Which product categories are most common among large households (size >= 4)?
SELECT
    p.category,
    COUNT(*) AS n_purchases
FROM purchases p
JOIN survey s
    ON p.survey_response_id = s.survey_response_id
WHERE s.hh_size >= 4
GROUP BY p.category
ORDER BY n_purchases DESC
LIMIT 20;


-- Users who buy kid items vs. those who don't — household size comparison
SELECT
    CASE WHEN k.n_kid_items > 0 THEN 'Buys kid items' ELSE 'No kid items' END AS segment,
    ROUND(AVG(s.hh_size), 2) AS avg_hh_size,
    COUNT(*) AS n_users
FROM survey s
LEFT JOIN kid_item_counts k
    ON s.survey_response_id = k.survey_response_id
GROUP BY segment;
