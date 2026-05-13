{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(month, city_name)',
    partition_by = 'toYYYYMM(month)'
  )
}}

select
    toStartOfMonth(e.dt)  as month,
    c.city_name           as city_name,
    cp.cp_name,
    e.doc_number,
    e.item_name,
    e.amount
from {{ ref('stg_expenses') }} e
join {{ ref('dim_city') }} c   on c.city_id = e.city_id
join {{ ref('dim_counterparty') }} cp on cp.cp_id = e.cp_id
where e.has_category = 0
order by month