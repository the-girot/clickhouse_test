{{
  config(
    materialized = 'table',
    engine = 'ReplacingMergeTree(_loaded_at_ts)',
    order_by = '(account_id)'
  )
}}

select
    toUInt32(account_id)                        as account_id,
    lower(trim(account_code))                   as account_code,
    trim(account_name)                          as account_name,
    trim(account_type)                          as account_type,
    lower(trim(statement_type))                 as statement_type,
    trim(bs_group)                              as bs_group,
    trim(cf_section)                            as cf_section,
    trim(pl_group)                              as pl_group,
    toInt8(pl_sign)                             as pl_sign,
    toUInt8(is_monetary)                        as is_monetary,
    lower(trim(normal_balance))                 as normal_balance,
    if(
        lower(trim(statement_type)) in ('pl', 'bs'), 1, 0
    )                                           as dq_valid_stmt_type,
    multiIf(
        trim(pl_group) = 'revenue', 'Выручка',
        trim(pl_group) = 'cogs', 'Себестоимость',
        trim(pl_group) = 'opex', 'Операционные расходы',
        trim(pl_group) = 'other', 'Прочие доходы/расходы',
        trim(pl_group) = 'tax', 'Налоги',
        trim(pl_group)
    )                                           as pl_group_label,
    multiIf(
        trim(bs_group) = 'current_assets', 'Оборотные активы',
        trim(bs_group) = 'noncurrent_assets', 'Внеоборотные активы',
        trim(bs_group) = 'current_liabilities', 'Краткосрочные обязательства',
        trim(bs_group) = 'noncurrent_liabilities', 'Долгосрочные обязательства',
        trim(bs_group) = 'equity', 'Капитал',
        trim(bs_group)
    )                                           as bs_group_label,
    toUnixTimestamp(now())                      as _loaded_at_ts
from {{ source('stg', 'stg_accounts') }}
where _is_deleted = 0
