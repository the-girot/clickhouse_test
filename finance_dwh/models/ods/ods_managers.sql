{{
  config(
    materialized = 'table',
    engine = 'ReplacingMergeTree(_loaded_at_ts)',
    order_by = '(manager_id)'
  )
}}

select
    toUInt32(manager_id)                        as manager_id,
    trim(full_name)                             as full_name,
    trim(department)                            as department,
    trim(region)                                as region,
    toDate(hire_date)                           as hire_date,
    lower(trim(status))                         as status,
    dateDiff('day', toDate(hire_date), today()) as tenure_days,
    multiIf(
        dateDiff('day', toDate(hire_date), today()) < 365, '<1yr',
        dateDiff('day', toDate(hire_date), today()) < 1095, '1-3yr',
        dateDiff('day', toDate(hire_date), today()) < 1825, '3-5yr',
        '5+yr'
    )                                           as tenure_group,
    toUnixTimestamp(now())                      as _loaded_at_ts
from (
    select *,
           row_number() over (partition by manager_id order by _ingested_at desc) as rn
    from {{ source('stg', 'stg_managers') }}
    where _is_deleted = 0
) where rn = 1
