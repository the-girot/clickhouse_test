{{
  config(
    materialized = 'table',
    engine = 'ReplacingMergeTree(_loaded_at_ts)',
    order_by = '(category, product_id)'
  )
}}

select
    toUInt32(product_id)                        as product_id,
    lower(trim(sku_code))                       as sku_code,
    trim(product_name)                          as product_name,
    trim(brand)                                 as brand,
    trim(category)                              as category,
    trim(subcategory)                           as subcategory,
    trim(unit_of_measure)                       as unit_of_measure,
    trim(pack_size)                             as pack_size,
    toDecimal64(base_price, 2)                  as base_price,
    toDecimal64(purchase_price, 2)              as purchase_price,
    toFloat32(vat_rate)                         as vat_rate,
    toUInt32(min_order_qty)                     as min_order_qty,
    toUInt32(supplier_id)                       as supplier_id,
    toUInt32(warehouse_id)                      as warehouse_id,
    toUInt8(is_active)                          as is_active,
    toDate(launched_at)                         as launched_at,
    round(
        (toDecimal64(base_price, 2) - toDecimal64(purchase_price, 2))
        / nullIf(toDecimal64(base_price, 2), 0) * 100,
        2
    )                                           as margin_pct,
    multiIf(
        round(
            (toDecimal64(base_price, 2) - toDecimal64(purchase_price, 2))
            / nullIf(toDecimal64(base_price, 2), 0) * 100,
            2
        ) >= 25, 'high',
        round(
            (toDecimal64(base_price, 2) - toDecimal64(purchase_price, 2))
            / nullIf(toDecimal64(base_price, 2), 0) * 100,
            2
        ) >= 15, 'mid',
        'low'
    )                                           as margin_group,
    round(
        toDecimal64(base_price, 2) * (1 + toFloat32(vat_rate)),
        2
    )                                           as price_with_vat,
    toUnixTimestamp(now())                      as _loaded_at_ts
from (
    select *,
           row_number() over (partition by product_id order by _ingested_at desc) as rn
    from {{ source('stg', 'stg_products') }}
    where _is_deleted = 0
) where rn = 1
