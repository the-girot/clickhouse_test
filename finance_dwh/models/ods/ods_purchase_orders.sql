{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(po_date, supplier_id, po_id)',
    partition_by = 'toYYYYMM(po_date)'
  )
}}

select
    toUInt32(po_id)                             as po_id,
    trim(po_code)                               as po_code,
    toUInt32(supplier_id)                       as supplier_id,
    toUInt32(warehouse_id)                      as warehouse_id,
    toDate(po_date)                             as po_date,
    toDate(expected_delivery)                   as expected_delivery,
    toDate(actual_delivery)                     as actual_delivery,
    lower(trim(status))                         as status,
    trim(currency_code)                         as currency_code,
    toDecimal64(total_amount, 2)                as total_amount,
    dateDiff(
        'day', toDate(expected_delivery), toDate(actual_delivery)
    )                                           as delivery_delay_days,
    if(
        toDate(actual_delivery) is not null,
        if(
            dateDiff('day', toDate(expected_delivery), toDate(actual_delivery)) <= 0,
            1, 0
        ),
        null
    )                                           as is_on_time,
    if(toDate(actual_delivery) is not null, 1, 0) as dq_has_delivery,
    toUnixTimestamp(now())                      as _loaded_at_ts
from (
    select *,
           row_number() over (partition by po_id order by _ingested_at desc) as rn
    from {{ source('stg', 'stg_purchase_orders') }}
    where _is_deleted = 0
) where rn = 1
