{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(invoice_date, invoice_type, counterparty_id, invoice_id)',
    partition_by = 'toYYYYMM(invoice_date)'
  )
}}

select
    toUInt32(invoice_id)                        as invoice_id,
    trim(invoice_code)                          as invoice_code,
    lower(trim(invoice_type))                   as invoice_type,
    toUInt32(counterparty_id)                   as counterparty_id,
    lower(trim(counterparty_type))              as counterparty_type,
    toUInt32(order_id)                          as order_id,
    toDate(invoice_date)                        as invoice_date,
    toDate(due_date)                            as due_date,
    trim(currency_code)                         as currency_code,
    toDecimal64(amount, 2)                      as amount,
    toDecimal64(paid_amount, 2)                 as paid_amount,
    toDecimal64(outstanding, 2)                 as outstanding,
    toInt32(days_overdue)                       as days_overdue,
    lower(trim(status))                         as status,
    multiIf(
        toInt32(days_overdue) <= 0, 'Current',
        toInt32(days_overdue) between 1 and 30, '1-30d',
        toInt32(days_overdue) between 31 and 60, '31-60d',
        toInt32(days_overdue) between 61 and 90, '61-90d',
        toInt32(days_overdue) > 90, '90d+',
        'Current'
    )                                           as aging_bucket,
    round(
        toDecimal64(paid_amount, 2) / nullIf(toDecimal64(amount, 2), 0) * 100,
        1
    )                                           as collection_rate,
    if(
        toInt32(days_overdue) > 0 and toDecimal64(outstanding, 2) > 0, 1, 0
    )                                           as is_overdue,
    toUnixTimestamp(now())                      as _loaded_at_ts
from (
    select *,
           row_number() over (partition by invoice_id order by _ingested_at desc) as rn
    from {{ source('stg', 'stg_invoices') }}
    where _is_deleted = 0
) where rn = 1
