{{
  config(
    materialized = 'table',
    engine = 'SummingMergeTree((ending_balance))',
    order_by = '(period, account_id, scenario_id)',
    partition_by = 'toYear(period)'
  )
}}

select
    toLastDayOfMonth(toStartOfMonth(posting_date))  as period,
    account_id                                      as account_id,
    bs_group                                        as bs_group,
    scenario_id                                     as scenario_id,
    sum(amount_base * if(normal_balance = 'debit', 1, -1)) as ending_balance
from {{ ref('fct_gl_entry') }}
where statement_type = 'bs'
group by
    toLastDayOfMonth(toStartOfMonth(posting_date)),
    account_id,
    bs_group,
    scenario_id
