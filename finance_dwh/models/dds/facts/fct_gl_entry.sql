{{
  config(
    materialized = 'incremental',
    unique_key = 'gl_id',
    incremental_strategy = 'delete+insert',
    engine = 'MergeTree()',
    partition_by = 'toYYYYMM(posting_date)',
    order_by = '(posting_date, account_id, scenario_id, gl_id)'
  )
}}

select
    toUInt64(g.gl_id)                              as gl_id,
    d.date_id                                       as date_id,
    g.posting_date                                  as posting_date,
    toStartOfMonth(g.posting_date)                  as posting_month,
    toUInt32(g.account_id)                          as account_id,
    toUInt32(g.contra_account_id)                   as contra_account_id,
    toUInt8(g.scenario_id)                          as scenario_id,
    g.doc_type                                      as doc_type,
    g.description                                   as description,
    a.statement_type                                as statement_type,
    a.pl_group                                      as pl_group,
    a.pl_sign                                       as pl_sign,
    a.bs_group                                      as bs_group,
    a.cf_section                                    as cf_section,
    a.is_monetary                                   as is_monetary,
    g.amount_base                                   as amount_base,
    if(a.pl_sign is not null, g.amount_base * a.pl_sign, null) as signed_amount,
    toUnixTimestamp(now())                          as _loaded_at_ts
from {{ ref('ods_gl_postings') }} g
left join {{ ref('dim_account') }} a on a.account_id = g.account_id
left join {{ ref('dim_date') }} d on d.date_actual = g.posting_date

{% if is_incremental() %}
where g.posting_date >= (select max(posting_date) - interval 3 day from {{ this }})
{% endif %}
