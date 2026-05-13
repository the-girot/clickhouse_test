{{
  config(
    materialized = 'view',
    schema = 'staging'
  )
}}

select
    toDate(dt)                              as dt,
    city_id,
    cp_id,
    cat_id,
    doc_number,
    toDecimal64(planned_sales, 2)  as planned_sales,
    toDecimal64(amount_to_pay, 2)  as amount_to_pay,
    toDecimal64(balance, 2)        as balance,
    toUInt8(is_paid)               as is_paid,
    toDate(due_date)               as due_date
from {{ source('raw', 'fact_payments') }}
where dt is not null
