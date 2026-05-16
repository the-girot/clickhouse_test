{{
  config(
    materialized = 'table',
    engine = 'SummingMergeTree((total_signed, total_raw, posting_count))',
    order_by = '(period, account_id, scenario_id)',
    partition_by = 'toYear(period)'
  )
}}

select
    toStartOfMonth(posting_date)                    as period,
    toYear(posting_date)                            as year,
    toQuarter(posting_date)                         as quarter,
    account_id                                      as account_id,
    pl_group                                        as pl_group,
    scenario_id                                     as scenario_id,
    sum(signed_amount)                              as total_signed,
    sum(amount_base)                                as total_raw,
    count(*)                                        as posting_count
from {{ ref('fct_gl_entry') }}
where statement_type = 'pl'
group by
    toStartOfMonth(posting_date),
    toYear(posting_date),
    toQuarter(posting_date),
    account_id,
    pl_group,
    scenario_id
