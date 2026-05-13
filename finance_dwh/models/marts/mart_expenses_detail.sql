{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(dt, city_name)',
    partition_by = 'toYYYYMM(month)'
  )
}}

select
    e.dt                          as dt,
    toStartOfMonth(e.dt)          as month,
    c.city_name                   as city_name,
    cp.cp_name,
    ec.group_name,
    ec.group_stat,
    ec.stat_name,
    e.doc_number,
    e.item_name,
    e.amount,
    e.mc_flag,
    e.has_category
from {{ ref('stg_expenses') }} e
join {{ ref('dim_city') }} c              on c.city_id = e.city_id
join {{ ref('dim_counterparty') }} cp     on cp.cp_id  = e.cp_id
left join {{ ref('dim_expense_category') }} ec on ec.cat_id = e.cat_id