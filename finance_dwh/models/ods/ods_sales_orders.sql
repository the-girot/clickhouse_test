{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(order_date, client_id, order_id)',
    partition_by = 'toYYYYMM(order_date)'
  )
}}

select
    toUInt32(order_id)                          as order_id,
    trim(order_code)                            as order_code,
    toUInt32(client_id)                         as client_id,
    toUInt32(manager_id)                        as manager_id,
    toUInt32(warehouse_id)                      as warehouse_id,
    toDate(order_date)                          as order_date,
    toDate(shipment_date)                       as shipment_date,
    lower(trim(status))                         as status,
    lower(trim(payment_status))                 as payment_status,
    trim(currency_code)                         as currency_code,
    toDecimal64(discount_pct, 4)                as discount_pct,
    toDecimal64(total_amount, 2)                as total_amount,
    toStartOfMonth(toDate(order_date))          as order_month,
    toYear(toDate(order_date))                  as order_year,
    toQuarter(toDate(order_date))               as order_quarter,
    toDayOfWeek(toDate(order_date))             as day_of_week,
    if(toDayOfWeek(toDate(order_date)) in (6, 7), 1, 0) as is_weekend,
    dateDiff('day', toDate(order_date), toDate(shipment_date)) as shipment_lag_days,
    if(toDecimal64(total_amount, 2) > 0, 1, 0) as dq_valid_amount,
    toUnixTimestamp(now())                      as _loaded_at_ts
from (
    select *,
           row_number() over (partition by order_id order by _ingested_at desc) as rn
    from {{ source('stg', 'stg_sales_orders') }}
    where _is_deleted = 0
) where rn = 1
