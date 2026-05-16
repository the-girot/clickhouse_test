{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(spend_date, platform, spend_id)',
    partition_by = 'toYYYYMM(spend_date)'
  )
}}

select
    toUInt32(spend_id)                          as spend_id,
    trim(campaign_id)                           as campaign_id,
    trim(campaign_name)                         as campaign_name,
    trim(platform)                              as platform,
    toDate(spend_date)                          as spend_date,
    toUInt32(impressions)                       as impressions,
    toUInt32(clicks)                            as clicks,
    toUInt32(conversions)                       as conversions,
    toDecimal64(spend_amount, 2)                as spend_amount,
    trim(currency_code)                         as currency_code,
    round(
        toUInt32(clicks) / nullIf(toUInt32(impressions), 0) * 100,
        3
    )                                           as ctr,
    round(
        toUInt32(conversions) / nullIf(toUInt32(clicks), 0) * 100,
        3
    )                                           as conversion_rate,
    round(
        toDecimal64(spend_amount, 2) / nullIf(toUInt32(clicks), 0),
        2
    )                                           as cpc,
    round(
        toDecimal64(spend_amount, 2) / nullIf(toUInt32(conversions), 0),
        2
    )                                           as cpa,
    toStartOfMonth(toDate(spend_date))          as spend_month,
    if(toDecimal64(spend_amount, 2) = 0, 1, 0)  as dq_zero_spend,
    toUnixTimestamp(now())                      as _loaded_at_ts
from (
    select *,
           row_number() over (partition by spend_id order by _ingested_at desc) as rn
    from {{ source('stg', 'stg_marketing_spend') }}
    where _is_deleted = 0
) where rn = 1
