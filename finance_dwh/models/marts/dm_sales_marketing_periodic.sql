{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    partition_by = 'toYear(period_start)',
    order_by = '(period_type, period_start, client_segment, product_category, scenario_id)'
  )
}}

with

-- Week + rolling_45d: from fct_sales_order_line (line-level)
so_fine as (
    select
        order_date,
        client_id,
        client_segment,
        client_region,
        product_id,
        product_category,
        product_brand,
        margin_group,
        quantity,
        line_revenue,
        line_cogs,
        line_gross_profit,
        order_id
    from {{ ref('fct_sales_order_line') }}
    where order_status != 'cancelled'
),

-- Month + quarter: from int_sales_monthly (pre-aggregated)
sales_mq as (
    select
        period,
        year,
        quarter,
        client_segment,
        product_category,
        revenue,
        cogs,
        gross_profit,
        quantity,
        order_count
    from {{ ref('int_sales_monthly') }}
),

-- Marketing spend raw
mkt_raw as (
    select
        spend_date,
        spend_amount,
        impressions,
        clicks,
        conversions
    from {{ ref('fct_marketing_spend') }}
),

-- Marketing spend aggregated by week
mkt_week as (
    select
        toMonday(spend_date) as period_start,
        sum(spend_amount) as mkt_spend,
        sum(impressions) as mkt_impressions,
        sum(clicks) as mkt_clicks,
        sum(conversions) as mkt_conversions,
        round(toFloat32(sum(clicks) / nullIf(sum(impressions), 0) * 100), 3) as mkt_ctr,
        round(sum(spend_amount) / nullIf(sum(conversions), 0), 2) as mkt_cpa
    from mkt_raw
    group by toMonday(spend_date)
),

-- Marketing spend aggregated by month
mkt_month as (
    select
        toStartOfMonth(spend_date) as period_start,
        sum(spend_amount) as mkt_spend,
        sum(impressions) as mkt_impressions,
        sum(clicks) as mkt_clicks,
        sum(conversions) as mkt_conversions,
        round(toFloat32(sum(clicks) / nullIf(sum(impressions), 0) * 100), 3) as mkt_ctr,
        round(sum(spend_amount) / nullIf(sum(conversions), 0), 2) as mkt_cpa
    from mkt_raw
    group by toStartOfMonth(spend_date)
),

-- Marketing spend aggregated by quarter
mkt_quarter as (
    select
        toStartOfQuarter(spend_date) as period_start,
        sum(spend_amount) as mkt_spend,
        sum(impressions) as mkt_impressions,
        sum(clicks) as mkt_clicks,
        sum(conversions) as mkt_conversions,
        round(toFloat32(sum(clicks) / nullIf(sum(impressions), 0) * 100), 3) as mkt_ctr,
        round(sum(spend_amount) / nullIf(sum(conversions), 0), 2) as mkt_cpa
    from mkt_raw
    group by toStartOfQuarter(spend_date)
),

-- Marketing spend aggregated by rolling 45d month-end windows
mkt_rolling as (
    select
        me.period_end,
        sum(m.spend_amount) as mkt_spend,
        sum(m.impressions) as mkt_impressions,
        sum(m.clicks) as mkt_clicks,
        sum(m.conversions) as mkt_conversions,
        round(toFloat32(sum(m.clicks) / nullIf(sum(m.impressions), 0) * 100), 3) as mkt_ctr,
        round(sum(m.spend_amount) / nullIf(sum(m.conversions), 0), 2) as mkt_cpa
    from (select distinct toLastDayOfMonth(spend_date) as period_end from mkt_raw) me
    inner join mkt_raw m on m.spend_date between me.period_end - interval 44 day and me.period_end
    group by me.period_end
),

-- Month-end dates for rolling 45d (from dim_date)
month_ends as (
    select date_actual as period_end
    from {{ ref('dim_date') }}
    where is_month_end = 1
),

-- Week grain
week_grain as (
    select
        'week'                                              as period_type,
        toMonday(s.order_date)                              as period_start,
        toMonday(s.order_date) + interval 6 day             as period_end,
        formatDateTime(toMonday(s.order_date), '%Y-W%V')    as period_label,
        toYear(s.order_date)                                as year,
        toQuarter(s.order_date)                             as quarter,
        s.client_segment,
        s.product_category,
        1                                                   as scenario_id,
        'Факт'                                              as scenario_name,
        sum(s.line_revenue)                                 as revenue,
        sum(s.line_cogs)                                    as cogs,
        sum(s.line_gross_profit)                            as gross_profit,
        round(toFloat32(
            sum(s.line_gross_profit) / nullIf(sum(s.line_revenue), 0) * 100
        ), 2)                                               as gross_margin_pct,
        sum(s.quantity)                                     as quantity,
        uniqExact(s.order_id)                               as order_count,
        round(sum(s.line_revenue) / nullIf(uniqExact(s.order_id), 0), 2) as avg_order_value,
        uniqExact(s.client_id)                              as unique_clients,
        coalesce(m.mkt_spend, 0)                            as marketing_spend,
        coalesce(m.mkt_impressions, 0)                      as impressions,
        coalesce(m.mkt_clicks, 0)                           as clicks,
        coalesce(m.mkt_conversions, 0)                      as conversions,
        coalesce(m.mkt_ctr, 0)                              as ctr,
        coalesce(m.mkt_cpa, 0)                              as cpa,
        round(toFloat32(
            (sum(s.line_gross_profit) - coalesce(m.mkt_spend, 0))
            / nullIf(coalesce(m.mkt_spend, 0), 0) * 100
        ), 2)                                               as romi
    from so_fine s
    left join mkt_week m on m.period_start = toMonday(s.order_date)
    group by toMonday(s.order_date), toYear(s.order_date), toQuarter(s.order_date),
             s.client_segment, s.product_category, m.mkt_spend, m.mkt_impressions,
             m.mkt_clicks, m.mkt_conversions, m.mkt_ctr, m.mkt_cpa
),

-- Month grain
month_grain as (
    select
        'month'                                             as period_type,
        sm.period                                           as period_start,
        toLastDayOfMonth(sm.period)                         as period_end,
        formatDateTime(sm.period, '%Y-%m')                  as period_label,
        sm.year                                             as year,
        sm.quarter                                          as quarter,
        sm.client_segment,
        sm.product_category,
        1                                                   as scenario_id,
        'Факт'                                              as scenario_name,
        sm.revenue,
        sm.cogs,
        sm.gross_profit,
        round(toFloat32(
            sm.gross_profit / nullIf(sm.revenue, 0) * 100
        ), 2)                                               as gross_margin_pct,
        sm.quantity,
        sm.order_count,
        round(sm.revenue / nullIf(sm.order_count, 0), 2)    as avg_order_value,
        0                                                   as unique_clients,
        coalesce(m.mkt_spend, 0)                            as marketing_spend,
        coalesce(m.mkt_impressions, 0)                      as impressions,
        coalesce(m.mkt_clicks, 0)                           as clicks,
        coalesce(m.mkt_conversions, 0)                      as conversions,
        coalesce(m.mkt_ctr, 0)                              as ctr,
        coalesce(m.mkt_cpa, 0)                              as cpa,
        round(toFloat32(
            (sm.gross_profit - coalesce(m.mkt_spend, 0))
            / nullIf(coalesce(m.mkt_spend, 0), 0) * 100
        ), 2)                                               as romi
    from sales_mq sm
    left join mkt_month m on m.period_start = sm.period
),

-- Quarter grain
quarter_grain as (
    select
        'quarter'                                           as period_type,
        toStartOfQuarter(sm.period)                         as period_start,
        toLastDayOfQuarter(sm.period)                       as period_end,
        concat(toString(sm.year), '-Q', toString(sm.quarter)) as period_label,
        sm.year                                             as year,
        sm.quarter                                          as quarter,
        sm.client_segment,
        sm.product_category,
        1                                                   as scenario_id,
        'Факт'                                              as scenario_name,
        sum(sm.revenue)                                     as revenue,
        sum(sm.cogs)                                        as cogs,
        sum(sm.gross_profit)                                as gross_profit,
        round(toFloat32(
            sum(sm.gross_profit) / nullIf(sum(sm.revenue), 0) * 100
        ), 2)                                               as gross_margin_pct,
        sum(sm.quantity)                                    as quantity,
        sum(sm.order_count)                                 as order_count,
        round(sum(sm.revenue) / nullIf(sum(sm.order_count), 0), 2) as avg_order_value,
        0                                                   as unique_clients,
        coalesce(m.mkt_spend, 0)                            as marketing_spend,
        coalesce(m.mkt_impressions, 0)                      as impressions,
        coalesce(m.mkt_clicks, 0)                           as clicks,
        coalesce(m.mkt_conversions, 0)                      as conversions,
        coalesce(m.mkt_ctr, 0)                              as ctr,
        coalesce(m.mkt_cpa, 0)                              as cpa,
        round(toFloat32(
            (sum(sm.gross_profit) - coalesce(m.mkt_spend, 0))
            / nullIf(coalesce(m.mkt_spend, 0), 0) * 100
        ), 2)                                               as romi
    from sales_mq sm
    left join mkt_quarter m on m.period_start = toStartOfQuarter(sm.period)
    group by toStartOfQuarter(sm.period), toLastDayOfQuarter(sm.period), sm.year,
             sm.quarter, sm.client_segment, sm.product_category,
             m.mkt_spend, m.mkt_impressions, m.mkt_clicks, m.mkt_conversions,
             m.mkt_ctr, m.mkt_cpa
),

-- Rolling 45d grain
rolling_45d_grain as (
    select
        'rolling_45d'                                       as period_type,
        me.period_end - interval 44 day                     as period_start,
        me.period_end                                       as period_end,
        concat(toString(me.period_end - interval 44 day), ' \u2192 ', toString(me.period_end)) as period_label,
        toYear(me.period_end)                               as year,
        toQuarter(me.period_end)                            as quarter,
        s.client_segment,
        s.product_category,
        1                                                   as scenario_id,
        'Факт'                                              as scenario_name,
        sum(s.line_revenue)                                 as revenue,
        sum(s.line_cogs)                                    as cogs,
        sum(s.line_gross_profit)                            as gross_profit,
        round(toFloat32(
            sum(s.line_gross_profit) / nullIf(sum(s.line_revenue), 0) * 100
        ), 2)                                               as gross_margin_pct,
        sum(s.quantity)                                     as quantity,
        uniqExact(s.order_id)                               as order_count,
        round(sum(s.line_revenue) / nullIf(uniqExact(s.order_id), 0), 2) as avg_order_value,
        uniqExact(s.client_id)                              as unique_clients,
        coalesce(m.mkt_spend, 0)                            as marketing_spend,
        coalesce(m.mkt_impressions, 0)                      as impressions,
        coalesce(m.mkt_clicks, 0)                           as clicks,
        coalesce(m.mkt_conversions, 0)                      as conversions,
        coalesce(m.mkt_ctr, 0)                              as ctr,
        coalesce(m.mkt_cpa, 0)                              as cpa,
        round(toFloat32(
            (sum(s.line_gross_profit) - coalesce(m.mkt_spend, 0))
            / nullIf(coalesce(m.mkt_spend, 0), 0) * 100
        ), 2)                                               as romi
    from month_ends me
    inner join so_fine s on s.order_date between me.period_end - interval 44 day and me.period_end
    left join mkt_rolling m on m.period_end = me.period_end
    group by me.period_end, s.client_segment, s.product_category,
             m.mkt_spend, m.mkt_impressions, m.mkt_clicks, m.mkt_conversions,
             m.mkt_ctr, m.mkt_cpa
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
    c.*,
    toUnixTimestamp(now()) as _loaded_at_ts
from combined c
