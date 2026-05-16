{{
  config(
    engine = 'MergeTree()',
    order_by = '(company_id)'
  )
}}

select
    company_id,
    company_name,
    company_short,
    inn,
    kpp,
    legal_address,
    industry,
    base_currency,
    fiscal_year_start_month,
    fiscal_year_end_month,
    founded_at,
    _loaded_at_ts
from {{ ref('ods_company') }}
