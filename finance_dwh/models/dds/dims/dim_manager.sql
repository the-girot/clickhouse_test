{{
  config(
    engine = 'ReplacingMergeTree(_loaded_at_ts)',
    order_by = '(manager_id)'
  )
}}

select
    manager_id,
    full_name,
    department,
    region,
    hire_date,
    status,
    tenure_days,
    tenure_group,
    _loaded_at_ts
from {{ ref('ods_managers') }}
