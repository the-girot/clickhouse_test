{{
  config(
    materialized = 'table',
    engine = 'SummingMergeTree()',
    order_by = '(month, city_name)',
    partition_by = 'toYYYYMM(month)'
  )
}}

select
    p.month,
    c.city_name,
    sum(p.revenue)      as revenue,
    sum(p.gross_profit) as gross_profit,
    sum(p.ebitda)       as ebitda,
    sum(p.net_profit)   as net_profit,
    round(
        sum(p.net_profit) / nullIf(sum(p.revenue), 0) * 100, 1
    ) as net_margin_pct,
    round(
        sum(p.ebitda) / nullIf(sum(p.revenue), 0) * 100, 1
    ) as ebitda_margin_pct,
    round(
        sum(p.gross_profit) / nullIf(sum(p.revenue), 0) * 100, 1
    ) as gross_margin_pct
from {{ ref('stg_pnl') }} p
join {{ ref('dim_city') }} c on c.city_id = p.city_id
group by p.month, c.city_name
