select count(*) from raw_engagement re ;


-- text -> number; TBD / Not Recorded / Unknown / N/A / blank -> 0
CREATE OR REPLACE FUNCTION fn_num(t TEXT) RETURNS NUMERIC AS $$
    SELECT COALESCE(
        CASE WHEN regexp_replace(t, '[^0-9.\-]', '', 'g') ~ '^-?[0-9]+(\.[0-9]+)?$'
             THEN regexp_replace(t, '[^0-9.\-]', '', 'g')::NUMERIC END, 0)
$$ LANGUAGE sql IMMUTABLE;

-- text -> date; handles DD-MM-YYYY and YYYY-MM-DD, Pending/TBD -> NULL
CREATE OR REPLACE FUNCTION fn_date(t TEXT) RETURNS DATE AS $$
    SELECT CASE WHEN trim(t) ~ '^\d{2}-\d{2}-\d{4}$' THEN to_date(trim(t), 'DD-MM-YYYY')
                WHEN trim(t) ~ '^\d{4}-\d{2}-\d{2}'  THEN left(trim(t), 10)::DATE END
$$ LANGUAGE sql IMMUTABLE;

-- label cleanup; placeholders -> 'Unknown'
CREATE OR REPLACE FUNCTION fn_txt(t TEXT) RETURNS TEXT AS $$
    SELECT CASE WHEN upper(trim(coalesce(t,''))) IN ('','TBD','N/A','PENDING','UNKNOWN','NOT RECORDED')
                THEN 'Unknown' ELSE initcap(trim(t)) END
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE VIEW vw_engagement AS
WITH c AS (
    SELECT
        engagement_record_id                                   AS record_id,
        fn_date(recorded_date)                                 AS recorded_date,
        fn_txt(client_name_raw)                                AS client_name,
        fn_txt(client_industry)                                AS industry,
        fn_txt(service_line_raw)                               AS service_line,
        fn_txt(project_name_raw)                               AS project_name,
        fn_txt(region_raw)                                     AS region,
        fn_txt(office_raw)                                     AS office,
        CASE WHEN upper(trim(employee_id_raw)) LIKE 'EMP-%'
             THEN upper(trim(employee_id_raw)) END             AS employee_id,
        fn_txt(employee_grade_raw)                             AS grade,
        fn_txt(work_type_raw)                                  AS work_type,
        fn_num(planned_hours_raw)                              AS planned_hours,
        fn_num(billable_hours_raw)                             AS billable_hours,
        fn_num(utilization_pct_raw)                            AS utilization_pct,
        CASE WHEN fn_num(project_progress_raw) BETWEEN 0 AND 100
             THEN fn_num(project_progress_raw) ELSE 0 END      AS progress_pct,
        fn_num(project_budget_inr_raw)                         AS budget_inr,
        fn_num(cost_recorded_inr_raw)                          AS cost_inr,
        fn_num(revenue_recorded_inr_raw)                       AS revenue_inr,
        fn_num(margin_recorded_inr)                            AS margin_inr,
        CASE lower(replace(replace(trim(project_status_raw),'-',' '),'_',' '))
             WHEN 'active'    THEN 'Active'
             WHEN 'at risk'   THEN 'At Risk'
             WHEN 'on hold'   THEN 'On Hold'
             WHEN 'completed' THEN 'Completed'
             WHEN 'cancelled' THEN 'Cancelled'
             WHEN 'canceled'  THEN 'Cancelled'
             ELSE 'Unknown' END                                AS status,
        fn_txt(milestone_raw)                                  AS milestone,
        fn_txt(engagement_partner_raw)                         AS partner,
        fn_txt(risk_or_issue_raw)                              AS risk_type,
        CASE WHEN upper(trim(risk_severity_raw)) IN ('LOW','MEDIUM','HIGH','CRITICAL')
             THEN initcap(trim(risk_severity_raw))
             WHEN upper(trim(risk_severity_raw)) IN ('N/A','NONE') THEN 'None'
             ELSE 'Unknown' END                                AS risk_severity,
        fn_date(planned_end_date)                              AS planned_end_date,
        fn_date(actual_end_date_cleaned)                       AS actual_end_date
    FROM raw_engagement
)
SELECT c.*,
    (status IN ('At Risk','On Hold'))::INT                              AS is_at_risk_hold,
    (status IN ('Active','At Risk','On Hold'))::INT                     AS is_open,
    (status IN ('Active','At Risk','On Hold')
        AND planned_end_date < DATE '2026-10-15')::INT                  AS is_overdue,
    (risk_severity IN ('High','Critical'))::INT                         AS is_high_critical,
    (risk_severity IN ('High','Critical') AND progress_pct >= 75)::INT  AS is_late_high_risk,
    (revenue_inr > 0)::INT                                              AS is_billed
FROM c;


select *
from vw_engagement;


