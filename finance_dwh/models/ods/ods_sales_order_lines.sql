{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(order_id, order_line_id)',
    partition_by = 'toYYYYMM(now())'
  )
}}

select
    toUInt32(order_line_id)                     as order_line_id,
    toUInt32(order_id)                          as order_id,
    toUInt32(product_id)                        as product_id,
    lower(trim(sku_code))                       as sku_code,
    trim(category)                              as category,
    trim(brand)                                 as brand,
    toUInt32(quantity)                          as quantity,
    toDecimal64(unit_price, 2)                  as unit_price,
    toDecimal64(unit_cost, 2)                   as unit_cost,
    toDecimal64(line_revenue, 2)                as line_revenue,
    toDecimal64(line_cogs, 2)                   as line_cogs,
    toDecimal64(line_gross_profit, 2)           as line_gross_profit,
    round(
        toDecimal64(line_gross_profit, 2) / nullIf(toDecimal64(line_revenue, 2), 0) * 100,
        2
    )                                           as gross_margin_pct,
    if(toDecimal64(line_gross_profit, 2) < 0, 1, 0) as dq_negative_margin,
    if(toDecimal64(unit_price, 2) = 0, 1, 0)    as dq_zero_price,
    toUnixTimestamp(now())                      as _loaded_at_ts
from (
    select *,
           row_number() over (partition by order_line_id order by _ingested_at desc) as rn
    from {{ source('stg', 'stg_sales_order_lines') }}
    where _is_deleted = 0
) where rn = 1
