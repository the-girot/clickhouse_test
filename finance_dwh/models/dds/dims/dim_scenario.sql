{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(scenario_id)'
  )
}}

select
    scenario_id,
    scenario_code,
    scenario_name,
    is_actual,
    toUnixTimestamp(now()) as _loaded_at_ts
from
(
    select 1 as scenario_id, 'ACTUAL' as scenario_code, 'Факт' as scenario_name, 1 as is_actual
    union all
    select 2, 'BUDGET', 'Бюджет', 0
    union all
    select 3, 'FORECAST', 'Прогноз', 0
    union all
    select 4, 'REFORECAST', 'Перепрогноз', 0
)
