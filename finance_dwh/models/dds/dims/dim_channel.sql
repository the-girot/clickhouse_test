{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(channel_id)'
  )
}}

select
    channel_id,
    channel_code,
    channel_name,
    channel_type,
    if(channel_type = 'Digital', 1, 0) as is_digital,
    toUnixTimestamp(now()) as _loaded_at_ts
from
(
    select 1 as channel_id, 'DIRECT' as channel_code, 'Прямые продажи' as channel_name, 'Sales' as channel_type
    union all
    select 2, 'ONLINE', 'Интернет-магазин', 'Digital'
    union all
    select 3, 'MARKETPLACE', 'Маркетплейс', 'Digital'
    union all
    select 4, 'PARTNER', 'Партнёрская сеть', 'Indirect'
    union all
    select 5, 'TELESALES', 'Телефонные продажи', 'Sales'
    union all
    select 6, 'FIELD', 'Полевые продажи', 'Sales'
)
