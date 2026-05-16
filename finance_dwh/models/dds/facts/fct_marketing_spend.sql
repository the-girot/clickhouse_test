{{
  config(
    materialized = 'incremental',
    unique_key = 'spend_id',
    incremental_strategy = 'delete+insert',
    engine = 'MergeTree()',
    partition_by = 'toYYYYMM(spend_date)',
    order_by = '(spend_date, platform, campaign_id, spend_id)'
  )
}}

select
    toUInt64(s.spend_id)                            as spend_id,
    d.date_id                                       as date_id,
    s.spend_date                                    as spend_date,
    toStartOfMonth(s.spend_date)                    as spend_month,
    toYear(s.spend_date)                            as spend_year,
    toQuarter(s.spend_date)                         as spend_quarter,
    toUInt32(s.campaign_id)                         as campaign_id,
    s.campaign_name                                 as campaign_name,
    'unknown'                                       as campaign_type,
    s.platform                                      as platform,
    s.impressions                                   as impressions,
    s.clicks                                        as clicks,
    s.conversions                                   as conversions,
    s.spend_amount                                  as spend_amount,
    s.ctr                                           as ctr,
    s.conversion_rate                               as conversion_rate,
    s.cpc                                           as cpc,
    s.cpa                                           as cpa,
    toUnixTimestamp(now())                          as _loaded_at_ts
from {{ ref('ods_marketing_spend') }} s
left join {{ ref('dim_date') }} d on d.date_actual = s.spend_date

{% if is_incremental() %}
where s.spend_date >= (select max(spend_date) - interval 3 day from {{ this }})
{% endif %}
