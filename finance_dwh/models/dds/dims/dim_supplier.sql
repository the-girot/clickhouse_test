{{
  config(
    engine = 'ReplacingMergeTree(_loaded_at_ts)',
    order_by = '(supplier_id)'
  )
}}

select
    supplier_id,
    supplier_name,
    supplier_code,
    country_code,
    payment_terms_days,
    credit_limit,
    status,
    supplier_country_group,
    _loaded_at_ts
from {{ ref('ods_suppliers') }}
