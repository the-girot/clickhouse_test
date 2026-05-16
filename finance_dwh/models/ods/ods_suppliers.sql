{{
  config(
    materialized = 'table',
    engine = 'ReplacingMergeTree(_loaded_at_ts)',
    order_by = '(supplier_id)'
  )
}}

select
    toUInt32(supplier_id)                       as supplier_id,
    trim(supplier_name)                         as supplier_name,
    lower(trim(supplier_code))                  as supplier_code,
    trim(country_code)                          as country_code,
    toUInt8(payment_terms_days)                 as payment_terms_days,
    toDecimal64(credit_limit, 2)                as credit_limit,
    lower(trim(status))                         as status,
    multiIf(
        trim(country_code) = 'RU', 'domestic',
        'foreign'
    )                                           as supplier_country_group,
    toUnixTimestamp(now())                      as _loaded_at_ts
from (
    select *,
           row_number() over (partition by supplier_id order by _ingested_at desc) as rn
    from {{ source('stg', 'stg_suppliers') }}
    where _is_deleted = 0
) where rn = 1
