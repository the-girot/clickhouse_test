{{
  config(
    materialized = 'incremental',
    unique_key = 'po_line_id',
    incremental_strategy = 'delete+insert',
    engine = 'MergeTree()',
    partition_by = 'toYYYYMM(po_date)',
    order_by = '(po_date, supplier_id, product_id, po_line_id)'
  )
}}

select
    toUInt64(pl.po_line_id)                        as po_line_id,
    toUInt64(pl.po_id)                              as po_id,
    d.date_id                                       as date_id,
    po.po_date                                      as po_date,
    toStartOfMonth(po.po_date)                      as po_month,
    po.supplier_id                                  as supplier_id,
    po.warehouse_id                                 as warehouse_id,
    pl.product_id                                   as product_id,
    s.supplier_name                                 as supplier_name,
    s.supplier_country_group                        as supplier_country_group,
    p.category                                      as product_category,
    p.brand                                         as product_brand,
    pl.quantity                                     as quantity,
    pl.received_qty                                 as received_qty,
    pl.unit_price                                   as unit_price,
    pl.line_amount                                  as line_amount,
    pl.receipt_pct                                  as receipt_pct,
    po.status                                       as po_status,
    if(po.is_on_time = 1, 1, 0)                    as is_on_time,
    toUnixTimestamp(now())                          as _loaded_at_ts
from {{ ref('ods_purchase_order_lines') }} pl
inner join {{ ref('ods_purchase_orders') }} po on po.po_id = pl.po_id
left join {{ ref('dim_date') }} d on d.date_actual = po.po_date
left join {{ ref('dim_supplier') }} s on s.supplier_id = po.supplier_id
left join {{ ref('dim_product') }} p on p.product_id = pl.product_id
left join {{ ref('dim_warehouse') }} w on w.warehouse_id = po.warehouse_id

{% if is_incremental() %}
where po.po_date >= (select max(po_date) - interval 3 day from {{ this }})
{% endif %}
