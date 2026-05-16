{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(po_id, po_line_id)'
  )
}}

select
    toUInt32(po_line_id)                        as po_line_id,
    toUInt32(po_id)                             as po_id,
    toUInt32(product_id)                        as product_id,
    lower(trim(sku_code))                       as sku_code,
    trim(category)                              as category,
    toUInt32(quantity)                          as quantity,
    toDecimal64(unit_price, 2)                  as unit_price,
    toDecimal64(line_amount, 2)                 as line_amount,
    toUInt32(received_qty)                      as received_qty,
    round(
        toUInt32(received_qty) / nullIf(toUInt32(quantity), 0) * 100,
        1
    )                                           as receipt_pct,
    if(toUInt32(received_qty) > toUInt32(quantity), 1, 0) as dq_qty_mismatch,
    toUnixTimestamp(now())                      as _loaded_at_ts
from (
    select *,
           row_number() over (partition by po_line_id order by _ingested_at desc) as rn
    from {{ source('stg', 'stg_purchase_order_lines') }}
    where _is_deleted = 0
) where rn = 1
