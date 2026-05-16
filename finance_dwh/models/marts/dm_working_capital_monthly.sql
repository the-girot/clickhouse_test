{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    partition_by = 'toYear(period)',
    order_by = '(period, invoice_type, counterparty_segment)'
  )
}}

with

inv_data as (
    select
        invoice_date,
        toStartOfMonth(invoice_date) as period,
        invoice_type,
        counterparty_segment,
        invoice_id,
        amount,
        paid_amount,
        outstanding,
        days_overdue,
        collection_rate,
        aging_bucket,
        is_overdue
    from {{ ref('fct_invoice') }}
)

select
    period,
    toYear(period)                                      as year,
    toQuarter(period)                                   as quarter,
    toMonth(period)                                     as month,
    invoice_type,
    counterparty_segment,
    count(invoice_id)                                   as invoice_count,
    sum(amount)                                         as total_invoiced,
    sum(paid_amount)                                    as total_paid,
    sum(outstanding)                                    as total_outstanding,
    round(toFloat32(
        sum(paid_amount) / nullIf(sum(amount), 0) * 100
    ), 2)                                               as collection_rate_pct,
    sumIf(outstanding, aging_bucket = 'Current')        as bucket_current,
    sumIf(outstanding, aging_bucket = '1-30d')          as bucket_1_30,
    sumIf(outstanding, aging_bucket = '31-60d')         as bucket_31_60,
    sumIf(outstanding, aging_bucket = '61-90d')         as bucket_61_90,
    sumIf(outstanding, aging_bucket = '90d+')           as bucket_90plus,
    avg(days_overdue)                                   as avg_days_overdue,
    countIf(is_overdue = 1)                             as overdue_invoice_count,
    round(toFloat32(
        countIf(is_overdue = 1) / nullIf(count(invoice_id), 0) * 100
    ), 2)                                               as overdue_pct,
    sumIf(outstanding, invoice_type = 'ar')             as outstanding_ar,
    sumIf(outstanding, invoice_type = 'ap')             as outstanding_ap,
    toUnixTimestamp(now())                              as _loaded_at_ts
from inv_data
group by
    period,
    toYear(period),
    toQuarter(period),
    toMonth(period),
    invoice_type,
    counterparty_segment
