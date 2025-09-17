-- =========================================================
-- HR Analytics, tenure and performance with window functions
-- SQLite compatible
-- =========================================================

PRAGMA foreign_keys = ON;

-- ------------------------
-- 1) Base tables
-- ------------------------
DROP TABLE IF EXISTS employees;
CREATE TABLE employees (
  employee_id    INTEGER PRIMARY KEY,
  name           TEXT NOT NULL,
  department     TEXT NOT NULL,
  hire_date      TEXT NOT NULL,      -- ISO date, YYYY-MM-DD
  termination_date TEXT              -- NULL means active
);

DROP TABLE IF EXISTS monthly_sales;
CREATE TABLE monthly_sales (
  id            INTEGER PRIMARY KEY,
  employee_id   INTEGER NOT NULL,
  month         TEXT NOT NULL,       -- YYYY-MM
  sales_amount  REAL NOT NULL,
  FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);

-- ------------------------
-- 2) Seed data, small but realistic
-- ------------------------
INSERT INTO employees (employee_id, name, department, hire_date, termination_date) VALUES
  (1,'Ava Johnson','Sales','2019-03-14',NULL),
  (2,'Liam Smith','Sales','2020-07-01',NULL),
  (3,'Mia Chen','Sales','2018-11-03','2024-05-15'),
  (4,'Noah Patel','Marketing','2021-01-10',NULL),
  (5,'Emma Davis','Marketing','2017-08-21','2023-09-30'),
  (6,'Oliver Brown','Engineering','2016-05-05',NULL),
  (7,'Sophia Wilson','Engineering','2019-10-19',NULL),
  (8,'James Taylor','Engineering','2022-02-01',NULL);

-- 12 months of sales for last year for a subset
WITH months(m) AS (
  SELECT '2024-01' UNION ALL SELECT '2024-02' UNION ALL SELECT '2024-03' UNION ALL
  SELECT '2024-04' UNION ALL SELECT '2024-05' UNION ALL SELECT '2024-06' UNION ALL
  SELECT '2024-07' UNION ALL SELECT '2024-08' UNION ALL SELECT '2024-09' UNION ALL
  SELECT '2024-10' UNION ALL SELECT '2024-11' UNION ALL SELECT '2024-12'
)
INSERT INTO monthly_sales (employee_id, month, sales_amount)
SELECT e.employee_id,
       m.m,
       -- toy generator: dept baseline + person variance + seasonal pulse
       CASE e.department
         WHEN 'Sales' THEN 50000
         WHEN 'Marketing' THEN 30000
         ELSE 20000
       END
       + (ABS((e.employee_id * 137) % 7000))         -- person variance
       + CASE substr(m.m, 6, 2)
            WHEN '11' THEN 8000                       -- seasonal uptick
            WHEN '12' THEN 12000
            ELSE 0
         END
FROM employees e
JOIN months m;

-- ------------------------
-- 3) Tenure metrics
-- ------------------------
DROP VIEW IF EXISTS v_employee_tenure_days;
CREATE VIEW v_employee_tenure_days AS
SELECT
  e.employee_id,
  e.name,
  e.department,
  e.hire_date,
  e.termination_date,
  -- tenure in days as of today or termination date
  ROUND(
    JULIANDAY(COALESCE(e.termination_date, DATE('now'))) - JULIANDAY(e.hire_date),
    1
  ) AS tenure_days
FROM employees e;

-- Average tenure by department
DROP VIEW IF EXISTS v_department_tenure_summary;
CREATE VIEW v_department_tenure_summary AS
SELECT
  department,
  ROUND(AVG(tenure_days), 1) AS avg_tenure_days,
  COUNT(*) AS headcount,
  SUM(CASE WHEN termination_date IS NULL THEN 1 ELSE 0 END) AS active_count
FROM v_employee_tenure_days
GROUP BY department
ORDER BY avg_tenure_days DESC;

-- ------------------------
-- 4) Performance ranks with window functions
-- ------------------------
-- Department, month, employee leaderboard
DROP VIEW IF EXISTS v_dept_month_leaderboard;
CREATE VIEW v_dept_month_leaderboard AS
SELECT
  e.department,
  ms.month,
  e.employee_id,
  e.name,
  ms.sales_amount,
  RANK() OVER (PARTITION BY e.department, ms.month ORDER BY ms.sales_amount DESC) AS dept_rank,
  ROUND(
    AVG(ms.sales_amount) OVER (PARTITION BY e.department, ms.month)
  ,2) AS dept_avg_sales
FROM monthly_sales ms
JOIN employees e ON e.employee_id = ms.employee_id;

-- ------------------------
-- 5) Example outputs
-- ------------------------

-- 5.1 Top 3 by department per month
-- SELECT * FROM v_dept_month_leaderboard WHERE dept_rank <= 3 ORDER BY department, month, dept_rank;

-- 5.2 Department tenure summary
-- SELECT * FROM v_department_tenure_summary;

-- 5.3 Longest tenured employees overall
-- SELECT * FROM v_employee_tenure_days ORDER BY tenure_days DESC LIMIT 10;

