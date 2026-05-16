{{
  config(
    materialized = 'incremental',
    unique_key = 'order_line_id',
    incremental_strategy = 'delete+insert',
    engine = 'MergeTree()',
    partition_by = 'toYYYYMM(order_date)',
    order_by = '(order_date, client_id, product_id, order_line_id)'
  )
}}

select
    toUInt64(sl.order_line_id)                     as order_line_id,
    toUInt64(sl.order_id)                          as order_id,
    d.date_id                                       as date_id,
    so.order_date                                   as order_date,
    toStartOfMonth(so.order_date)                   as order_month,
    toYear(so.order_date)                           as order_year,
    toQuarter(so.order_date)                        as order_quarter,
    so.client_id                                    as client_id,
    so.manager_id                                   as manager_id,
    so.warehouse_id                                 as warehouse_id,
    sl.product_id                                   as product_id,
    1                                               as scenario_id,
    c.segment                                       as client_segment,
    c.region                                        as client_region,
    p.category                                      as product_category,
    p.brand                                         as product_brand,
    p.margin_group                                  as margin_group,
    sl.quantity                                     as quantity,
    sl.unit_price                                   as unit_price,
    sl.unit_cost                                    as unit_cost,
    so.discount_pct                                 as discount_pct,
    sl.line_revenue                                 as line_revenue,
    sl.line_cogs                                    as line_cogs,
    sl.line_gross_profit                            as line_gross_profit,
    sl.gross_margin_pct                             as gross_margin_pct,
    so.status                                       as order_status,
    so.payment_status                               as payment_status,
    toUnixTimestamp(now())                          as _loaded_at_ts
from {{ ref('ods_sales_order_lines') }} sl
inner join {{ ref('ods_sales_orders') }} so on so.order_id = sl.order_id
left join {{ ref('dim_date') }} d on d.date_actual = so.order_date
left join {{ ref('dim_client') }} c on c.client_id = so.client_id
left join {{ ref('dim_product') }} p on p.product_id = sl.product_id
left join {{ ref('dim_manager') }} m on m.manager_id = so.manager_id
left join {{ ref('dim_warehouse') }} w on w.warehouse_id = so.warehouse_id

{% if is_incremental() %}
where so.order_date >= (select max(order_date) - interval 3 day from {{ this }})
{% endif %}
