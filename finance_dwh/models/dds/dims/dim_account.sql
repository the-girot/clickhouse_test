{{
  config(
    engine = 'ReplacingMergeTree(_loaded_at_ts)',
    order_by = '(account_id)'
  )
}}

select
    account_id,
    account_code,
    account_name,
    account_type,
    statement_type,
    bs_group,
    cf_section,
    pl_group,
    pl_sign,
    is_monetary,
    normal_balance,
    dq_valid_stmt_type,
    pl_group_label,
    bs_group_label,
    concat(
        statement_type,
        ' / ',
        coalesce(nullIf(trim(pl_group), ''), nullIf(trim(bs_group), ''), nullIf(trim(cf_section), ''), 'Other')
    ) as full_account_path,
    _loaded_at_ts
from {{ ref('ods_accounts') }}
