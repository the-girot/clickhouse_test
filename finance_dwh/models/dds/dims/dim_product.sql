{{
  config(
    engine = 'ReplacingMergeTree(_loaded_at_ts)',
    order_by = '(category, product_id)'
  )
}}

select
    product_id,
    sku_code,
    product_name,
    brand,
    category,
    subcategory,
    unit_of_measure,
    pack_size,
    base_price,
    purchase_price,
    vat_rate,
    min_order_qty,
    supplier_id,
    warehouse_id,
    is_active,
    launched_at,
    margin_pct,
    margin_group,
    price_with_vat,
    if(margin_group = 'high', 1, 0) as is_high_margin,
    'unknown' as abc_class,
    _loaded_at_ts
from {{ ref('ods_products') }}
