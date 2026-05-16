{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(invoice_type, aging_bucket, counterparty_id, invoice_id)'
  )
}}

select
    i.invoice_id,
    i.invoice_code,
    i.invoice_type,
    i.invoice_date,
    i.due_date,
    i.days_overdue,
    i.aging_bucket,
    i.counterparty_id,
    i.counterparty_name,
    i.counterparty_type,
    i.counterparty_segment,
    i.counterparty_region,
    i.amount,
    i.paid_amount,
    i.outstanding,
    toFloat32(i.collection_rate)                        as collection_rate,
    multiIf(
        i.aging_bucket = 'Current', 'low',
        i.aging_bucket in ('1-30d', '31-60d'), 'medium',
        i.aging_bucket in ('61-90d', '90d+'), 'high',
        'unknown'
    )                                                   as risk_level,
    toUnixTimestamp(now())                              as _loaded_at_ts,
    toDate(now())                                       as snapshot_date
from {{ ref('fct_invoice') }} i
where i.outstanding > 0
