{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(due_date, cp_name)'
  )
}}

select
    p.due_date            as due_date,
    cp.cp_name            as cp_name,
    ec.stat_name          as expense_stat,
    sum(p.amount_to_pay)  as total_amount
from {{ ref('stg_payments') }} p
join {{ ref('dim_counterparty') }} cp on cp.cp_id = p.cp_id
join {{ ref('dim_expense_category') }} ec on ec.cat_id = p.cat_id
where p.is_paid = 0
group by p.due_date, cp.cp_name, ec.stat_name
order by p.due_date