{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(posting_date, account_id, gl_id)',
    partition_by = 'toYYYYMM(posting_date)'
  )
}}

select
    toUInt32(g.gl_id)                           as gl_id,
    toDate(g.posting_date)                      as posting_date,
    trim(g.doc_type)                            as doc_type,
    toUInt32(g.account_id)                      as account_id,
    toUInt32(g.contra_account_id)               as contra_account_id,
    toDecimal64(g.amount_base, 2)               as amount_base,
    trim(g.currency_code)                       as currency_code,
    trim(g.description)                         as description,
    toUInt32(g.scenario_id)                     as scenario_id,
    a.statement_type                            as statement_type,
    a.pl_group                                  as pl_group,
    a.pl_sign                                   as pl_sign,
    a.bs_group                                  as bs_group,
    a.cf_section                                as cf_section,
    a.is_monetary                               as is_monetary,
    a.normal_balance                            as normal_balance,
    if(a.pl_sign is not null,
       toDecimal64(g.amount_base, 2) * a.pl_sign,
       null
    )                                           as signed_amount,
    toStartOfMonth(toDate(g.posting_date))      as posting_month,
    toYear(toDate(g.posting_date))              as posting_year,
    if(a.account_id is null, 1, 0)              as dq_missing_account,
    toUnixTimestamp(now())                      as _loaded_at_ts
from (
    select *,
           row_number() over (partition by gl_id order by _ingested_at desc) as rn
    from {{ source('stg', 'stg_gl_postings') }}
    where _is_deleted = 0
) g
left join {{ ref('ods_accounts') }} a on a.account_id = toUInt32(g.account_id)
