{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(dt)',
    partition_by = 'toYYYYMM(dt)'
  )
}}

select
    dt,
    sum(planned_sales) as planned_sales,
    sum(amount_to_pay) as amount_to_pay,
    sum(balance)       as balance
from {{ ref('stg_payments') }}
group by dt
order by dt
