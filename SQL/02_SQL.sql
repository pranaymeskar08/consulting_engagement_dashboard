/* ===== 01_kpi_cards.csv ===== */
SELECT
    COUNT(*)                                              AS total_records,
    COUNT(DISTINCT client_name)                           AS clients,
    ROUND(100.0 * SUM(is_at_risk_hold) / COUNT(*), 1)     AS at_risk_hold_pct,
    SUM(is_overdue)                                       AS overdue_open_records,
    SUM(is_high_critical)                                 AS high_critical_risks,
    ROUND(AVG(utilization_pct), 1)                        AS avg_utilization_pct,
    ROUND(100.0 * SUM(margin_inr) FILTER (WHERE is_billed = 1)
                / NULLIF(SUM(revenue_inr) FILTER (WHERE is_billed = 1), 0), 1) AS margin_pct_billed,
    COUNT(*) FILTER (WHERE employee_id IS NULL)           AS missing_employee_id_rows
FROM vw_engagement;


/* ===== 02_delivery_risk.csv ===== Q1: where are projects at risk? */
SELECT d.dimension, d.segment,
       COUNT(*)                                          AS records,
       SUM(is_at_risk_hold)                              AS at_risk_hold_records,
       ROUND(100.0 * SUM(is_at_risk_hold) / COUNT(*), 1) AS at_risk_hold_pct,
       SUM(is_open)                                      AS open_records,
       SUM(is_overdue)                                   AS overdue_records,
       ROUND(100.0 * SUM(is_overdue) / NULLIF(SUM(is_open), 0), 1) AS overdue_pct_of_open
FROM vw_engagement
CROSS JOIN LATERAL (VALUES ('status', status), ('service_line', service_line), ('industry', industry),
                           ('region', region), ('partner', partner)) d(dimension, segment)
GROUP BY d.dimension, d.segment
ORDER BY d.dimension, at_risk_hold_pct DESC;


/* ===== 03_utilization.csv ===== Q2: are teams deployed effectively? */
SELECT d.dimension, d.segment,
       COUNT(*)                                                  AS records,
       ROUND(AVG(utilization_pct), 1)                            AS avg_utilization_pct,
       ROUND(AVG(utilization_pct) FILTER (WHERE work_type = 'Client Delivery'), 1) AS avg_util_client_delivery,
       ROUND(100.0 * SUM(is_at_risk_hold) / COUNT(*), 1)         AS at_risk_hold_pct
FROM vw_engagement
CROSS JOIN LATERAL (VALUES ('grade', grade), ('work_type', work_type), ('office', office),
                           ('region', region), ('service_line', service_line),
                           ('month', to_char(recorded_date, 'YYYY-MM'))) d(dimension, segment)
GROUP BY d.dimension, d.segment
ORDER BY d.dimension, d.segment;


/* ===== 04_commercial.csv ===== Q3: which work looks commercially healthy? */
SELECT d.dimension, d.segment,
       COUNT(*)                                   AS records,
       ROUND(SUM(cost_inr), 0)                    AS total_cost,
       ROUND(SUM(revenue_inr), 0)                 AS total_revenue,
       ROUND(100.0 * SUM(margin_inr) FILTER (WHERE is_billed = 1)
                   / NULLIF(SUM(revenue_inr) FILTER (WHERE is_billed = 1), 0), 1) AS margin_pct_billed,
       COUNT(*) FILTER (WHERE is_billed = 0)      AS zero_revenue_rows,
       COUNT(*) FILTER (WHERE is_billed = 1 AND margin_inr < 0) AS negative_margin_billed_rows
FROM vw_engagement
CROSS JOIN LATERAL (VALUES ('service_line', service_line), ('industry', industry),
                           ('region', region), ('client', client_name), ('project', project_name)) d(dimension, segment)
GROUP BY d.dimension, d.segment
ORDER BY d.dimension, total_revenue DESC;


/* ===== 05_risk_patterns.csv ===== Q4: what risk pattern should be escalated? */
SELECT d.dimension, d.segment,
       COUNT(*)                                            AS records,
       SUM(is_high_critical)                               AS high_critical_records,
       ROUND(100.0 * SUM(is_high_critical) / COUNT(*), 1)  AS high_critical_pct,
       SUM(is_late_high_risk)                              AS late_stage_high_risk,
       ROUND(100.0 * COUNT(*) FILTER (WHERE risk_type = 'None Reported') / COUNT(*), 1) AS none_reported_pct
FROM vw_engagement
CROSS JOIN LATERAL (VALUES ('risk_type', risk_type), ('risk_severity', risk_severity), ('milestone', milestone),
                           ('service_line', service_line), ('region', region), ('industry', industry)) d(dimension, segment)
GROUP BY d.dimension, d.segment
ORDER BY d.dimension, high_critical_pct DESC;


/* ===== 06_portfolio_mix.csv ===== Q5: where is work concentrated? */
SELECT dimension, segment, records, clients, revenue,
       ROUND(100.0 * records / SUM(records) OVER (PARTITION BY dimension), 1)            AS record_share_pct,
       ROUND(100.0 * revenue / NULLIF(SUM(revenue) OVER (PARTITION BY dimension), 0), 1) AS revenue_share_pct
FROM (
    SELECT d.dimension, d.segment,
           COUNT(*)                      AS records,
           COUNT(DISTINCT client_name)   AS clients,
           ROUND(SUM(revenue_inr), 0)    AS revenue
    FROM vw_engagement
    CROSS JOIN LATERAL (VALUES ('service_line', service_line), ('industry', industry),
                               ('region', region), ('office', office), ('client', client_name)) d(dimension, segment)
    GROUP BY d.dimension, d.segment
) t
ORDER BY dimension, revenue DESC;



---===============================
--====================================
--====================================
/* ===== 09_risk_type_by_severity.csv ===== Q4: which risk types carry the most severe risks? */
SELECT risk_type,
       risk_severity,
       CASE risk_severity WHEN 'Critical' THEN 1 WHEN 'High' THEN 2
                          WHEN 'Medium'   THEN 3 WHEN 'Low'  THEN 4 END AS severity_order,
       COUNT(*) AS records
FROM vw_engagement
WHERE risk_type NOT IN ('None Reported', 'Unknown')
  AND risk_severity IN ('Critical', 'High', 'Medium', 'Low')
GROUP BY risk_type, risk_severity
ORDER BY risk_type, severity_order;


SELECT
    MIN(recorded_date) AS earliest_date,
    MAX(recorded_date) AS latest_date
FROM vw_engagement;
