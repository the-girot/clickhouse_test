{{
  config(
    materialized = 'table',
    engine = 'ReplacingMergeTree(_loaded_at_ts)',
    order_by = '(warehouse_id)'
  )
}}

select
    toUInt32(warehouse_id)                      as warehouse_id,
    lower(trim(warehouse_code))                 as warehouse_code,
    trim(warehouse_name)                        as warehouse_name,
    trim(address)                               as address,
    trim(region)                                as region,
    toUInt8(is_active)                          as is_active,
    multiIf(
        toUInt32(warehouse_id) = 1, 'primary',
        'secondary'
    )                                           as warehouse_tier,
    toUnixTimestamp(now())                      as _loaded_at_ts
from (
    select *,
           row_number() over (partition by warehouse_id order by _ingested_at desc) as rn
    from {{ source('stg', 'stg_warehouses') }}
    where _is_deleted = 0
) where rn = 1
