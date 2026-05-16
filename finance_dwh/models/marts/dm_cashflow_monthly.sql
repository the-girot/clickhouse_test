{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    partition_by = 'toYear(period)',
    order_by = '(period, scenario_id)'
  )
}}

with

-- P&L: net profit and depreciation per month
pnl_data as (
    select
        period,
        scenario_id,
        sumIf(total_signed, pl_group = 'revenue')          as revenue,
        sumIf(total_signed, pl_group = 'cogs')             as total_cogs,
        - sumIf(total_signed, pl_group = 'depreciation')   as depreciation,
        sumIf(total_signed, pl_group = 'revenue')
            + sumIf(total_signed, pl_group = 'cogs')       as net_profit
    from {{ ref('int_pnl_monthly') }}
    group by period, scenario_id
),

-- Balance sheet: current + previous month BS balances by bs_group
bs_data as (
    select
        curr.period,
        curr.scenario_id,
        curr.bs_group,
        curr.ending_balance as curr_balance,
        prev.ending_balance as prev_balance
    from {{ ref('int_balance_monthly') }} curr
    left join {{ ref('int_balance_monthly') }} prev
        on prev.account_id = curr.account_id
        and prev.scenario_id = curr.scenario_id
        and prev.period = toStartOfMonth(toDate(curr.period) - interval 1 month)
),

bs_agg as (
    select
        period,
        scenario_id,
        sumIf(curr_balance, bs_group = 'current_assets')    as curr_ca,
        sumIf(prev_balance, bs_group = 'current_assets')    as prev_ca,
        sumIf(curr_balance, bs_group = 'current_liabilities')  as curr_cl,
        sumIf(prev_balance, bs_group = 'current_liabilities')  as prev_cl,
        sumIf(curr_balance, bs_group = 'noncurrent_assets')    as curr_nca,
        sumIf(prev_balance, bs_group = 'noncurrent_assets')    as prev_nca,
        sumIf(curr_balance, bs_group = 'equity')               as curr_eq,
        sumIf(prev_balance, bs_group = 'equity')               as prev_eq
    from bs_data
    group by period, scenario_id
)

select
    p.period,
    toYear(p.period)                      as year,
    toQuarter(p.period)                   as quarter,
    toMonth(p.period)                     as month,
    p.scenario_id,
    sc.scenario_name,
    p.net_profit,
    p.depreciation,
    coalesce(b.curr_ca - b.prev_ca, 0) as delta_ar,
    coalesce(b.curr_cl - b.prev_cl, 0) as delta_ap,
    coalesce(b.curr_ca - b.prev_ca
        - (b.curr_nca - b.prev_nca), 0)  as delta_inventory,
    p.net_profit
        + p.depreciation
        - coalesce(b.curr_ca - b.prev_ca, 0)
        + coalesce(b.curr_cl - b.prev_cl, 0)
        - coalesce(b.curr_ca - b.prev_ca
            - (b.curr_nca - b.prev_nca), 0)                as operating_cf,
    -(coalesce(b.curr_nca - b.prev_nca, 0) - p.depreciation) as investing_cf,
    coalesce(null, 0)                                        as financing_cf,
    p.net_profit
        + p.depreciation
        - coalesce(b.curr_ca - b.prev_ca, 0)
        + coalesce(b.curr_cl - b.prev_cl, 0)
        - coalesce(b.curr_ca - b.prev_ca
            - (b.curr_nca - b.prev_nca), 0)
        - (coalesce(b.curr_nca - b.prev_nca, 0) - p.depreciation) as net_cash_flow,
    sum(
        p.net_profit
            + p.depreciation
            - coalesce(b.curr_ca - b.prev_ca, 0)
            + coalesce(b.curr_cl - b.prev_cl, 0)
            - coalesce(b.curr_ca - b.prev_ca
                - (b.curr_nca - b.prev_nca), 0)
    ) over (
        partition by p.scenario_id, toYear(p.period)
        order by p.period
        rows between unbounded preceding and current row
    )                                                        as operating_cf_ytd,
    sum(
        p.net_profit
            + p.depreciation
            - coalesce(b.curr_ca - b.prev_ca, 0)
            + coalesce(b.curr_cl - b.prev_cl, 0)
            - coalesce(b.curr_ca - b.prev_ca
                - (b.curr_nca - b.prev_nca), 0)
            - (coalesce(b.curr_nca - b.prev_nca, 0) - p.depreciation)
    ) over (
        partition by p.scenario_id, toYear(p.period)
        order by p.period
        rows between unbounded preceding and current row
    )                                                        as net_cash_flow_ytd,
    coalesce(b.prev_ca, 0)                                    as opening_cash,
    coalesce(b.curr_ca, 0)                                    as closing_cash,
    toUnixTimestamp(now())                                    as _loaded_at_ts
from pnl_data p
left join bs_agg b on b.period = p.period and b.scenario_id = p.scenario_id
left join {{ ref('dim_scenario') }} sc on sc.scenario_id = p.scenario_id
