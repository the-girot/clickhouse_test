{{
  config(
    engine = 'ReplacingMergeTree(_loaded_at_ts)',
    order_by = '(warehouse_id)'
  )
}}

select
    warehouse_id,
    warehouse_code,
    warehouse_name,
    address,
    region,
    is_active,
    warehouse_tier,
    if(warehouse_id = 1, 1, 0) as is_primary,
    _loaded_at_ts
from {{ ref('ods_warehouses') }}
