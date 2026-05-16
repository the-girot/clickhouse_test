{{
  config(
    engine = 'ReplacingMergeTree(_loaded_at_ts)',
    order_by = '(client_id)'
  )
}}

select
    client_id,
    client_name,
    client_code,
    client_type,
    segment,
    region,
    inn,
    payment_terms_days,
    credit_limit,
    assigned_manager_id,
    warehouse_id,
    status,
    registered_at,
    segment_label,
    days_since_registration,
    dq_has_manager,
    'unknown' as ltv_tier,
    _loaded_at_ts
from {{ ref('ods_clients') }}
