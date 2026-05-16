{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    partition_by = 'toYear(period)',
    order_by = '(period, scenario_id)'
  )
}}

select
    b.period,
    toYear(b.period)                                 as year,
    toQuarter(b.period)                              as quarter,
    toMonth(b.period)                                as month,
    b.scenario_id,
    s.scenario_name,
    sumIf(b.ending_balance, b.bs_group = 'current_assets')       as current_assets,
    sumIf(b.ending_balance, b.bs_group = 'noncurrent_assets')    as non_current_assets,
    sumIf(b.ending_balance, b.bs_group = 'current_assets')
        + sumIf(b.ending_balance, b.bs_group = 'noncurrent_assets') as total_assets,
    sumIf(b.ending_balance, b.bs_group = 'current_liabilities')    as current_liabilities,
    sumIf(b.ending_balance, b.bs_group = 'noncurrent_liabilities') as non_current_liab,
    sumIf(b.ending_balance, b.bs_group = 'current_liabilities')
        + sumIf(b.ending_balance, b.bs_group = 'noncurrent_liabilities') as total_liabilities,
    sumIf(b.ending_balance, b.bs_group = 'equity')               as total_equity,
    sumIf(b.ending_balance, b.bs_group = 'current_liabilities')
        + sumIf(b.ending_balance, b.bs_group = 'noncurrent_liabilities')
        + sumIf(b.ending_balance, b.bs_group = 'equity')         as total_liab_equity,
    (sumIf(b.ending_balance, b.bs_group = 'current_assets')
        + sumIf(b.ending_balance, b.bs_group = 'noncurrent_assets'))
        - (sumIf(b.ending_balance, b.bs_group = 'current_liabilities')
            + sumIf(b.ending_balance, b.bs_group = 'noncurrent_liabilities')
            + sumIf(b.ending_balance, b.bs_group = 'equity'))    as balance_diff,
    if(
        abs(
            (sumIf(b.ending_balance, b.bs_group = 'current_assets')
                + sumIf(b.ending_balance, b.bs_group = 'noncurrent_assets'))
            - (sumIf(b.ending_balance, b.bs_group = 'current_liabilities')
                + sumIf(b.ending_balance, b.bs_group = 'noncurrent_liabilities')
                + sumIf(b.ending_balance, b.bs_group = 'equity'))
        ) < 1.0,
        1, 0
    )                                                           as is_balanced,
    round(toFloat32(
        sumIf(b.ending_balance, b.bs_group = 'current_assets')
        / nullIf(sumIf(b.ending_balance, b.bs_group = 'current_liabilities'), 0)
    ), 2)                                                       as current_ratio,
    round(toFloat32(
        (sumIf(b.ending_balance, b.bs_group = 'current_liabilities')
            + sumIf(b.ending_balance, b.bs_group = 'noncurrent_liabilities'))
        / nullIf(sumIf(b.ending_balance, b.bs_group = 'equity'), 0)
    ), 2)                                                       as debt_to_equity,
    round(toFloat32(
        sumIf(b.ending_balance, b.bs_group = 'equity')
        / nullIf(
            sumIf(b.ending_balance, b.bs_group = 'current_assets')
            + sumIf(b.ending_balance, b.bs_group = 'noncurrent_assets'),
            0
        ) * 100
    ), 2)                                                       as equity_ratio,
    toUnixTimestamp(now())                                      as _loaded_at_ts
from {{ ref('int_balance_monthly') }} b
left join {{ ref('dim_scenario') }} s on s.scenario_id = b.scenario_id
group by b.period, toYear(b.period), toQuarter(b.period), toMonth(b.period), b.scenario_id, s.scenario_name
