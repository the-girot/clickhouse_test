{{
  config(
    materialized = 'table',
    engine = 'ReplacingMergeTree(_loaded_at_ts)',
    order_by = '(client_id)'
  )
}}

select
    toUInt32(client_id)                         as client_id,
    trim(client_name)                           as client_name,
    lower(trim(client_code))                    as client_code,
    lower(trim(client_type))                    as client_type,
    trim(segment)                               as segment,
    trim(region)                                as region,
    trim(inn)                                   as inn,
    toUInt8(payment_terms_days)                 as payment_terms_days,
    toDecimal64(credit_limit, 2)                as credit_limit,
    toUInt32(assigned_manager_id)               as assigned_manager_id,
    toUInt32(warehouse_id)                      as warehouse_id,
    lower(trim(status))                         as status,
    toDate(registered_at)                       as registered_at,
    multiIf(
        trim(segment) = 'A', 'Крупный',
        trim(segment) = 'B', 'Средний',
        trim(segment) = 'C', 'Мелкий',
        trim(segment)
    )                                           as segment_label,
    dateDiff('day', toDate(registered_at), today()) as days_since_registration,
    if(toUInt32(assigned_manager_id) > 0, 1, 0) as dq_has_manager,
    toUnixTimestamp(now())                      as _loaded_at_ts
from (
    select *,
           row_number() over (partition by client_id order by _ingested_at desc) as rn
    from {{ source('stg', 'stg_clients') }}
    where _is_deleted = 0
) where rn = 1
