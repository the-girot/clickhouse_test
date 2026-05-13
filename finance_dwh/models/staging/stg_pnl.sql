{{
  config(
    materialized = 'view',
    schema = 'staging'
  )
}}

select
    toDate(month)                           as month,
    city_id,
    cat_id,
    toDecimal64(revenue, 2)        as revenue,
    toDecimal64(cogs, 2)           as cogs,
    toDecimal64(gross_profit, 2)   as gross_profit,
    toDecimal64(operating_cost, 2) as operating_cost,
    toDecimal64(ebitda, 2)         as ebitda,
    toDecimal64(net_profit, 2)     as net_profit,
    toDecimal64(tax, 2)            as tax
from {{ source('raw', 'fact_pnl') }}
where month is not null
  and city_id > 0
