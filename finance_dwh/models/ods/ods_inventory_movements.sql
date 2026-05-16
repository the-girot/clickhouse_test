{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(move_date, warehouse_id, product_id, move_id)',
    partition_by = 'toYYYYMM(move_date)'
  )
}}

select
    toUInt32(move_id)                           as move_id,
    lower(trim(move_type))                      as move_type,
    lower(trim(reference_type))                 as reference_type,
    toUInt32(reference_id)                      as reference_id,
    toUInt32(product_id)                        as product_id,
    toUInt32(warehouse_id)                      as warehouse_id,
    toInt32(quantity)                           as quantity,
    toDecimal64(unit_cost, 2)                   as unit_cost,
    toDate(move_date)                           as move_date,
    round(toInt32(quantity) * toDecimal64(unit_cost, 2), 2) as movement_value,
    if(toInt32(quantity) > 0, 'in', 'out')      as move_direction,
    if(toDecimal64(unit_cost, 2) = 0, 1, 0)     as dq_zero_cost,
    toUnixTimestamp(now())                      as _loaded_at_ts
from (
    select *,
           row_number() over (partition by move_id order by _ingested_at desc) as rn
    from {{ source('stg', 'stg_inventory_movements') }}
    where _is_deleted = 0
) where rn = 1
