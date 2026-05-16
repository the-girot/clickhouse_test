{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    partition_by = 'toYear(period)',
    order_by = '(period, scenario_id)'
  )
}}

with

-- Monthly P&L KPIs
pnl as (
    select
        period_start as period,
        scenario_id,
        revenue,
        gross_profit,
        gross_margin_pct,
        ebitda,
        ebitda_margin_pct,
        net_profit,
        net_margin_pct,
        revenue_ytd,
        net_profit_ytd
    from {{ ref('dm_pnl_periodic') }}
    where period_type = 'month'
),

-- Previous month P&L for MoM
prev_pnl as (
    select
        period_start as period,
        scenario_id,
        revenue as prev_revenue,
        net_profit as prev_net_profit
    from {{ ref('dm_pnl_periodic') }}
    where period_type = 'month'
),

-- Balance KPIs
balance as (
    select
        period,
        scenario_id,
        total_assets,
        total_equity,
        current_ratio,
        debt_to_equity
    from {{ ref('dm_balance_monthly') }}
),

-- Cashflow KPIs
cashflow as (
    select
        period,
        scenario_id,
        operating_cf,
        net_cash_flow,
        closing_cash
    from {{ ref('dm_cashflow_monthly') }}
),

combined as (
    select
        p.period,
        multiIf(
            toMonth(p.period) = 1, 'Январь',
            toMonth(p.period) = 2, 'Февраль',
            toMonth(p.period) = 3, 'Март',
            toMonth(p.period) = 4, 'Апрель',
            toMonth(p.period) = 5, 'Май',
            toMonth(p.period) = 6, 'Июнь',
            toMonth(p.period) = 7, 'Июль',
            toMonth(p.period) = 8, 'Август',
            toMonth(p.period) = 9, 'Сентябрь',
            toMonth(p.period) = 10, 'Октябрь',
            toMonth(p.period) = 11, 'Ноябрь',
            'Декабрь'
        ) || ' ' || toString(toYear(p.period))               as period_label,
        toYear(p.period)                                      as year,
        toQuarter(p.period)                                   as quarter,
        toMonth(p.period)                                     as month,
        p.scenario_id,
        s.scenario_name,
        p.revenue,
        p.gross_profit,
        p.gross_margin_pct,
        p.ebitda,
        p.ebitda_margin_pct,
        p.net_profit,
        p.net_margin_pct,
        round(toFloat32(
            (p.revenue - r.prev_revenue) / nullIf(r.prev_revenue, 0) * 100
        ), 2)                                                 as revenue_mom_pct,
        round(toFloat32(
            (p.net_profit - r.prev_net_profit) / nullIf(r.prev_net_profit, 0) * 100
        ), 2)                                                 as net_profit_mom_pct,
        p.revenue_ytd,
        p.net_profit_ytd,
        b.total_assets,
        b.total_equity,
        b.current_ratio,
        b.debt_to_equity,
        round(toFloat32(
            p.net_profit / nullIf(b.total_equity, 0) * 100
        ), 2)                                                 as roe,
        round(toFloat32(
            p.net_profit / nullIf(b.total_assets, 0) * 100
        ), 2)                                                 as roa,
        c.operating_cf,
        c.net_cash_flow,
        c.closing_cash,
        round(toFloat32(
            c.operating_cf / nullIf(p.net_profit, 0) * 100
        ), 2)                                                 as cash_conversion,
        toUnixTimestamp(now())                                as _loaded_at_ts
    from pnl p
    left join prev_pnl r
        on r.scenario_id = p.scenario_id
        and r.period = toStartOfMonth(toDate(p.period) - interval 1 month)
    left join balance b on b.period = p.period and b.scenario_id = p.scenario_id
    left join cashflow c on c.period = p.period and c.scenario_id = p.scenario_id
    left join {{ ref('dim_scenario') }} s on s.scenario_id = p.scenario_id
)

select * from combined
