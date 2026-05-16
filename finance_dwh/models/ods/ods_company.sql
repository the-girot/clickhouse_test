{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(company_id)'
  )
}}

select
    toUInt32(company_id)                        as company_id,
    trim(company_name)                          as company_name,
    trim(company_short)                         as company_short,
    trim(inn)                                   as inn,
    trim(kpp)                                   as kpp,
    trim(legal_address)                         as legal_address,
    trim(industry)                              as industry,
    trim(base_currency)                         as base_currency,
    toUInt8(fiscal_year_start_month)            as fiscal_year_start_month,
    if(
        toUInt8(fiscal_year_start_month) = 1, 12,
        toUInt8(fiscal_year_start_month) - 1
    )                                           as fiscal_year_end_month,
    toDate(founded_at)                          as founded_at,
    toUnixTimestamp(now())                      as _loaded_at_ts
from {{ source('stg', 'stg_company') }}
where _is_deleted = 0
