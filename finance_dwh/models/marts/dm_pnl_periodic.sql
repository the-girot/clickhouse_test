{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    partition_by = 'toYear(period_start)',
    order_by = '(period_type, period_start, scenario_id)'
  )
}}

with

-- Week + rolling_45d: from fct_gl_entry directly
gl_fine as (
    select
        posting_date,
        account_id,
        pl_group,
        pl_sign,
        scenario_id,
        amount_base,
        signed_amount
    from {{ ref('fct_gl_entry') }}
    where statement_type = 'pl'
),

-- Month + quarter: from int_pnl_monthly (pre-aggregated)
pnl_mq as (
    select
        period,
        year,
        quarter,
        account_id,
        pl_group,
        scenario_id,
        total_signed
    from {{ ref('int_pnl_monthly') }}
),

-- Week grain
week_grain as (
    select
        'week'                                              as period_type,
        toMonday(posting_date)                              as period_start,
        toMonday(posting_date) + interval 6 day             as period_end,
        formatDateTime(toMonday(posting_date), '%Y-W%V')    as period_label,
        toYear(posting_date)                                as year,
        toQuarter(posting_date)                             as quarter,
        toMonth(posting_date)                               as month,
        scenario_id                                         as scenario_id,
        - sumIf(signed_amount, pl_group = 'cogs')           as cogs,
        - sumIf(signed_amount, pl_group = 'opex')           as opex,
        - sumIf(signed_amount, pl_group = 'depreciation')   as depreciation,
        - sumIf(signed_amount, pl_group = 'financial')      as financial_exp,
        - sumIf(signed_amount, pl_group = 'tax')            as tax,
        sumIf(signed_amount, pl_group = 'revenue')          as revenue
    from gl_fine
    group by toMonday(posting_date), toYear(posting_date), toQuarter(posting_date), toMonth(posting_date), scenario_id
),

-- Month grain
month_grain as (
    select
        'month'                                             as period_type,
        period                                              as period_start,
        toLastDayOfMonth(period)                            as period_end,
        formatDateTime(period, '%Y-%m')                     as period_label,
        year                                                as year,
        quarter                                             as quarter,
        toMonth(period)                                     as month,
        scenario_id                                         as scenario_id,
        - sumIf(total_signed, pl_group = 'cogs')            as cogs,
        - sumIf(total_signed, pl_group = 'opex')            as opex,
        - sumIf(total_signed, pl_group = 'depreciation')    as depreciation,
        - sumIf(total_signed, pl_group = 'financial')       as financial_exp,
        - sumIf(total_signed, pl_group = 'tax')             as tax,
        sumIf(total_signed, pl_group = 'revenue')           as revenue
    from pnl_mq
    group by period, year, quarter, scenario_id
),

-- Quarter grain
quarter_grain as (
    select
        'quarter'                                           as period_type,
        toStartOfQuarter(period)                            as period_start,
        toLastDayOfQuarter(period)                          as period_end,
        concat(toString(year), '-Q', toString(quarter))     as period_label,
        year                                                as year,
        quarter                                             as quarter,
        toMonth(period)                                     as month,
        scenario_id                                         as scenario_id,
        - sumIf(total_signed, pl_group = 'cogs')            as cogs,
        - sumIf(total_signed, pl_group = 'opex')            as opex,
        - sumIf(total_signed, pl_group = 'depreciation')    as depreciation,
        - sumIf(total_signed, pl_group = 'financial')       as financial_exp,
        - sumIf(total_signed, pl_group = 'tax')             as tax,
        sumIf(total_signed, pl_group = 'revenue')           as revenue
    from pnl_mq
    group by toStartOfQuarter(period), toLastDayOfQuarter(period), year, quarter, scenario_id
),

-- Rolling 45d: compute on month-end dates only
rolling_45d_grain as (
    select
        'rolling_45d'                                       as period_type,
        d.period_end - interval 44 day                      as period_start,
        d.period_end                                        as period_end,
        concat(toString(d.period_end - interval 44 day), ' \u2192 ', toString(d.period_end)) as period_label,
        toYear(d.period_end)                                as year,
        toQuarter(d.period_end)                             as quarter,
        toMonth(d.period_end)                               as month,
        g.scenario_id                                       as scenario_id,
        - sumIf(g.signed_amount, g.pl_group = 'cogs')       as cogs,
        - sumIf(g.signed_amount, g.pl_group = 'opex')       as opex,
        - sumIf(g.signed_amount, g.pl_group = 'depreciation') as depreciation,
        - sumIf(g.signed_amount, g.pl_group = 'financial')  as financial_exp,
        - sumIf(g.signed_amount, g.pl_group = 'tax')        as tax,
        sumIf(g.signed_amount, g.pl_group = 'revenue')      as revenue
    from (select distinct toLastDayOfMonth(posting_date) as period_end from gl_fine) d
    inner join gl_fine g on g.posting_date between d.period_end - interval 44 day and d.period_end
    group by d.period_end, g.scenario_id
),

combined as (
    select * from week_grain
    union all
    select * from month_grain
    union all
    select * from quarter_grain
    union all
    select * from rolling_45d_grain
)

select
    c.period_type,
    c.period_start,
    c.period_end,
    c.period_label,
    c.year,
    c.quarter,
    c.month,
    c.scenario_id,
    s.scenario_name,
    c.revenue,
    c.cogs,
    c.revenue - c.cogs                                           as gross_profit,
    round(toFloat32((c.revenue - c.cogs) / nullIf(c.revenue, 0) * 100), 2) as gross_margin_pct,
    c.opex,
    c.depreciation,
    c.revenue - c.cogs - c.opex                                   as ebitda,
    round(toFloat32((c.revenue - c.cogs - c.opex) / nullIf(c.revenue, 0) * 100), 2) as ebitda_margin_pct,
    c.revenue - c.cogs - c.opex - c.depreciation                   as ebit,
    c.financial_exp,
    c.revenue - c.cogs - c.opex - c.depreciation - c.financial_exp as ebt,
    c.tax,
    c.revenue - c.cogs - c.opex - c.depreciation - c.financial_exp - c.tax as net_profit,
    round(toFloat32((c.revenue - c.cogs - c.opex - c.depreciation - c.financial_exp - c.tax) / nullIf(c.revenue, 0) * 100), 2) as net_margin_pct,
    multiIf(
        c.period_type = 'month',
        sum(c.revenue) over (partition by c.year, c.scenario_id order by c.period_start rows between unbounded preceding and current row),
        null
    )                                                            as revenue_ytd,
    multiIf(
        c.period_type = 'month',
        sum(c.revenue - c.cogs - c.opex - c.depreciation - c.financial_exp - c.tax)
            over (partition by c.year, c.scenario_id order by c.period_start rows between unbounded preceding and current row),
        null
    )                                                            as net_profit_ytd,
    toUnixTimestamp(now())                                       as _loaded_at_ts
from combined c
left join {{ ref('dim_scenario') }} s on s.scenario_id = c.scenario_id
