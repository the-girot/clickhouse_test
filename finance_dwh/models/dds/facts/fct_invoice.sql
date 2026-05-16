{{
  config(
    materialized = 'incremental',
    unique_key = 'invoice_id',
    incremental_strategy = 'delete+insert',
    engine = 'MergeTree()',
    partition_by = 'toYYYYMM(invoice_date)',
    order_by = '(invoice_date, invoice_type, counterparty_id, invoice_id)'
  )
}}

select
    toUInt64(i.invoice_id)                          as invoice_id,
    d.date_id                                       as date_id,
    i.invoice_date                                  as invoice_date,
    i.due_date                                      as due_date,
    toStartOfMonth(i.invoice_date)                  as invoice_month,
    i.invoice_type                                  as invoice_type,
    i.counterparty_id                               as counterparty_id,
    i.counterparty_type                             as counterparty_type,
    coalesce(dc.client_name, ds.supplier_name, 'Unknown') as counterparty_name,
    dc.segment                                      as counterparty_segment,
    dc.region                                       as counterparty_region,
    i.amount                                        as amount,
    i.paid_amount                                   as paid_amount,
    i.outstanding                                   as outstanding,
    i.days_overdue                                  as days_overdue,
    i.collection_rate                               as collection_rate,
    i.aging_bucket                                  as aging_bucket,
    i.is_overdue                                    as is_overdue,
    i.status                                        as status,
    toUnixTimestamp(now())                          as _loaded_at_ts
from {{ ref('ods_invoices') }} i
left join {{ ref('dim_date') }} d on d.date_actual = i.invoice_date
left join {{ ref('dim_client') }} dc on i.counterparty_id = dc.client_id and i.counterparty_type = 'client'
left join {{ ref('dim_supplier') }} ds on i.counterparty_id = ds.supplier_id and i.counterparty_type = 'supplier'

{% if is_incremental() %}
where i.invoice_date >= (select max(invoice_date) - interval 3 day from {{ this }})
{% endif %}
