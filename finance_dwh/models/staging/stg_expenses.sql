{{
  config(
    materialized = 'view',
    schema = 'staging'
  )
}}

select
    toDate(dt)                       as dt,
    city_id,
    cp_id,
    cat_id,
    doc_number,
    toUInt8(mc_flag)        as mc_flag,
    item_name,
    toDecimal64(amount, 2)  as amount,
    toUInt8(has_category)   as has_category
from {{ source('raw', 'fact_expenses') }}
where dt is not null
  and amount > 0
