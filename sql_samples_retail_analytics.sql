-- Retail Analytics - Cohorts, RFM, Margins
-- Works on plain SQLite. No extensions required.

PRAGMA foreign_keys = ON;

-- Drop if rerun
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;

-- 1) Schema
CREATE TABLE products (
  product_id     INTEGER PRIMARY KEY,
  category       TEXT NOT NULL,
  name           TEXT NOT NULL,
  unit_cost      REAL NOT NULL,
  unit_price     REAL NOT NULL
);

CREATE TABLE customers (
  customer_id          INTEGER PRIMARY KEY,
  signup_date          DATE NOT NULL,
  acquisition_channel  TEXT NOT NULL CHECK (acquisition_channel IN ('ads','organic','referral','partner'))
);

CREATE TABLE orders (
  order_id     INTEGER PRIMARY KEY,
  customer_id  INTEGER NOT NULL,
  order_date   DATE NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
  order_item_id INTEGER PRIMARY KEY,
  order_id      INTEGER NOT NULL,
  product_id    INTEGER NOT NULL,
  quantity      INTEGER NOT NULL CHECK (quantity > 0),
  FOREIGN KEY (order_id) REFERENCES orders(order_id),
  FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 2) Seed products
INSERT INTO products(product_id, category, name, unit_cost, unit_price) VALUES
 (1,'Widgets','Widget A',12.00,24.00),
 (2,'Widgets','Widget B',18.00,36.00),
 (3,'Widgets','Widget C',25.00,55.00),
 (4,'Gadgets','Gadget A',9.00,22.00),
 (5,'Gadgets','Gadget B',14.00,28.00),
 (6,'Gadgets','Gadget C',20.00,44.00),
 (7,'Accessories','Cable A',2.00,9.00),
 (8,'Accessories','Cable B',3.00,12.00),
 (9,'Accessories','Adapter A',4.00,16.00),
 (10,'Pro','Pro Kit A',80.00,160.00),
 (11,'Pro','Pro Kit B',120.00,240.00),
 (12,'Pro','Pro Kit C',160.00,320.00);

-- 3) Generate 200 customers over 2024
WITH RECURSIVE seq(n) AS (
  SELECT 1
  UNION ALL
  SELECT n+1 FROM seq WHERE n < 200
)
INSERT INTO customers(customer_id, signup_date, acquisition_channel)
SELECT
  n AS customer_id,
  date('2024-01-01','+' || (abs(random()) % 365) || ' day') AS signup_date,
  CASE abs(random()) % 4
    WHEN 0 THEN 'ads'
    WHEN 1 THEN 'organic'
    WHEN 2 THEN 'referral'
    ELSE 'partner'
  END AS acquisition_channel
FROM seq;

-- 4) Generate orders for each customer across 2024-2025
-- Up to 8 potential orders per customer, about 60 percent materialize
WITH RECURSIVE s(n) AS (
  SELECT 1
  UNION ALL
  SELECT n+1 FROM s WHERE n < 8
)
INSERT INTO orders(customer_id, order_date)
SELECT
  c.customer_id,
  date(c.signup_date, '+' || (abs(random()) % 540) || ' day') AS order_date
FROM customers c
JOIN s ON 1=1
WHERE (abs(random()) % 100) < 60;

-- 5) Generate 1-3 items per order, about 75 percent of item slots materialize
WITH RECURSIVE t(n) AS (
  SELECT 1
  UNION ALL
  SELECT n+1 FROM t WHERE n < 3
)
INSERT INTO order_items(order_id, product_id, quantity)
SELECT
  o.order_id,
  1 + (abs(random()) % (SELECT COUNT(*) FROM products)) AS product_id,
  1 + (abs(random()) % 4) AS quantity
FROM orders o
JOIN t ON 1=1
WHERE (abs(random()) % 100) < 75;

-- 6) Helpful views for revenue and margin
DROP VIEW IF EXISTS v_order_item_finance;
CREATE VIEW v_order_item_finance AS
SELECT
  oi.order_item_id,
  oi.order_id,
  oi.product_id,
  oi.quantity,
  p.category,
  p.name,
  p.unit_cost,
  p.unit_price,
  (oi.quantity * p.unit_price) AS revenue,
  (oi.quantity * p.unit_cost)  AS cost,
  ((oi.quantity * p.unit_price) - (oi.quantity * p.unit_cost)) AS margin
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id;

DROP VIEW IF EXISTS v_order_finance;
CREATE VIEW v_order_finance AS
SELECT
  o.order_id,
  o.customer_id,
  o.order_date,
  SUM(f.revenue) AS order_revenue,
  SUM(f.cost)    AS order_cost,
  SUM(f.margin)  AS order_margin
FROM orders o
JOIN v_order_item_finance f ON f.order_id = o.order_id
GROUP BY o.order_id, o.customer_id, o.order_date;

-- 7) Cohort retention by month for first 12 months
DROP VIEW IF EXISTS v_customer_first_month;
CREATE VIEW v_customer_first_month AS
SELECT
  o.customer_id,
  MIN(strftime('%Y-%m', o.order_date)) AS cohort_month
FROM orders o
GROUP BY o.customer_id;

DROP VIEW IF EXISTS v_orders_by_month;
CREATE VIEW v_orders_by_month AS
SELECT
  o.customer_id,
  strftime('%Y-%m', o.order_date) AS order_month
FROM orders o;

-- Final retention table
DROP TABLE IF EXISTS cohort_retention_12m;
CREATE TABLE cohort_retention_12m AS
WITH cohort_sizes AS (
  SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
  FROM v_customer_first_month
  GROUP BY cohort_month
),
activity AS (
  SELECT cf.cohort_month, obm.order_month, COUNT(DISTINCT obm.customer_id) AS active_customers
  FROM v_orders_by_month obm
  JOIN v_customer_first_month cf ON cf.customer_id = obm.customer_id
  GROUP BY cf.cohort_month, obm.order_month
),
retention AS (
  SELECT
    a.cohort_month,
    a.order_month,
    CAST(active_customers AS REAL) / cohort_size AS retention_rate,
    (
      (CAST(strftime('%Y', a.order_month || '-01') AS INT) * 12 + CAST(strftime('%m', a.order_month || '-01') AS INT))
      -
      (CAST(strftime('%Y', a.cohort_month || '-01') AS INT) * 12 + CAST(strftime('%m', a.cohort_month || '-01') AS INT))
    ) AS month_index
  FROM activity a
  JOIN cohort_sizes cs USING (cohort_month)
)
SELECT cohort_month, month_index, ROUND(retention_rate, 4) AS retention_rate
FROM retention
WHERE month_index BETWEEN 0 AND 11
ORDER BY cohort_month, month_index;

-- 8) RFM scoring with practical thresholds
-- Reference date is the max order_date in the dataset
DROP TABLE IF EXISTS rfm_scores;
CREATE TABLE rfm_scores AS
WITH ref AS (
  SELECT MAX(order_date) AS ref_date FROM orders
),
cust_orders AS (
  SELECT
    o.customer_id,
    MIN(o.order_date) AS first_order_date,
    MAX(o.order_date) AS last_order_date,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(f.order_revenue) AS total_revenue
  FROM orders o
  JOIN v_order_finance f ON f.order_id = o.order_id
  GROUP BY o.customer_id
),
base AS (
  SELECT
    c.customer_id,
    c.first_order_date,
    c.last_order_date,
    c.order_count,
    c.total_revenue,
    CAST((julianday(r.ref_date) - julianday(c.last_order_date)) AS INT) AS recency_days
  FROM cust_orders c
  CROSS JOIN ref r
)
SELECT
  b.customer_id,
  b.first_order_date,
  b.last_order_date,
  b.order_count,
  ROUND(b.total_revenue, 2) AS total_revenue,
  b.recency_days,
  -- Recency score: lower days is better
  CASE
    WHEN b.recency_days <= 30  THEN 5
    WHEN b.recency_days <= 90  THEN 4
    WHEN b.recency_days <= 180 THEN 3
    WHEN b.recency_days <= 365 THEN 2
    ELSE 1
  END AS r_score,
  -- Frequency score: more orders is better
  CASE
    WHEN b.order_count >= 12 THEN 5
    WHEN b.order_count >= 8  THEN 4
    WHEN b.order_count >= 5  THEN 3
    WHEN b.order_count >= 2  THEN 2
    ELSE 1
  END AS f_score,
  -- Monetary score: higher revenue is better
  CASE
    WHEN b.total_revenue >= 2000 THEN 5
    WHEN b.total_revenue >= 1200 THEN 4
    WHEN b.total_revenue >= 600  THEN 3
    WHEN b.total_revenue >= 200  THEN 2
    ELSE 1
  END AS m_score
FROM base b;

-- 9) Category margin contribution
DROP TABLE IF EXISTS category_margin_summary;
CREATE TABLE category_margin_summary AS
WITH cat AS (
  SELECT
    p.category,
    SUM(f.revenue) AS revenue,
    SUM(f.cost)    AS cost,
    SUM(f.margin)  AS margin
  FROM v_order_item_finance f
  JOIN products p ON p.product_id = f.product_id
  GROUP BY p.category
),
tot AS (
  SELECT SUM(margin) AS total_margin FROM cat
)
SELECT
  c.category,
  ROUND(c.revenue, 2) AS revenue,
  ROUND(c.cost, 2)    AS cost,
  ROUND(c.margin, 2)  AS margin,
  ROUND((c.margin / NULLIF(t.total_margin,0)) * 100.0, 2) AS pct_of_total_margin
FROM cat c
CROSS JOIN tot t
ORDER BY margin DESC;

-- 10) Helpful indexes
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id, order_date);
CREATE INDEX IF NOT EXISTS idx_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_items_product ON order_items(product_id);

-- 11) Result samples you can SELECT directly
-- SELECT * FROM cohort_retention_12m LIMIT 50;
-- SELECT * FROM rfm_scores ORDER BY r_score DESC, f_score DESC, m_score DESC LIMIT 20;
-- SELECT * FROM category_margin_summary;
