{{
  config(
    materialized = 'table',
    engine = 'SummingMergeTree((revenue, cogs, gross_profit, quantity, order_count))',
    order_by = '(period, client_id, product_id)',
    partition_by = 'toYear(period)'
  )
}}

select
    toStartOfMonth(order_date)                      as period,
    toYear(order_date)                              as year,
    toQuarter(order_date)                           as quarter,
    client_id                                       as client_id,
    client_segment                                  as client_segment,
    client_region                                   as client_region,
    product_id                                      as product_id,
    product_category                                as product_category,
    product_brand                                   as product_brand,
    margin_group                                    as margin_group,
    sum(line_revenue)                               as revenue,
    sum(line_cogs)                                  as cogs,
    sum(line_gross_profit)                          as gross_profit,
    sum(quantity)                                   as quantity,
    count(distinct order_id)                        as order_count
from {{ ref('fct_sales_order_line') }}
where order_status != 'cancelled'
group by
    toStartOfMonth(order_date),
    toYear(order_date),
    toQuarter(order_date),
    client_id,
    client_segment,
    client_region,
    product_id,
    product_category,
    product_brand,
    margin_group
