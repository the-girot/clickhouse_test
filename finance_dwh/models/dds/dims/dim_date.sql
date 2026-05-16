{{
  config(
    materialized = 'table',
    engine = 'MergeTree()',
    order_by = '(date_actual)'
  )
}}

with date_spine as (
    select toDate('2020-01-01') + number as date_actual
    from numbers(dateDiff('day', toDate('2020-01-01'), toDate('2030-12-31')) + 1)
)

select
    toInt32(replaceAll(toString(date_actual), '-', '')) as date_id,
    date_actual,
    toYear(date_actual)                                  as year,
    toQuarter(date_actual)                               as quarter,
    toMonth(date_actual)                                 as month,
    multiIf(
        toMonth(date_actual) = 1, 'Январь',
        toMonth(date_actual) = 2, 'Февраль',
        toMonth(date_actual) = 3, 'Март',
        toMonth(date_actual) = 4, 'Апрель',
        toMonth(date_actual) = 5, 'Май',
        toMonth(date_actual) = 6, 'Июнь',
        toMonth(date_actual) = 7, 'Июль',
        toMonth(date_actual) = 8, 'Август',
        toMonth(date_actual) = 9, 'Сентябрь',
        toMonth(date_actual) = 10, 'Октябрь',
        toMonth(date_actual) = 11, 'Ноябрь',
        toMonth(date_actual) = 12, 'Декабрь',
        ''
    )                                                   as month_name,
    toWeek(date_actual, 3)                               as week_of_year,
    toDayOfMonth(date_actual)                            as day_of_month,
    toDayOfWeek(date_actual, 1)                          as day_of_week,
    multiIf(
        toDayOfWeek(date_actual, 1) = 1, 'Понедельник',
        toDayOfWeek(date_actual, 1) = 2, 'Вторник',
        toDayOfWeek(date_actual, 1) = 3, 'Среда',
        toDayOfWeek(date_actual, 1) = 4, 'Четверг',
        toDayOfWeek(date_actual, 1) = 5, 'Пятница',
        toDayOfWeek(date_actual, 1) = 6, 'Суббота',
        toDayOfWeek(date_actual, 1) = 7, 'Воскресенье',
        ''
    )                                                   as day_name,
    if(toDayOfWeek(date_actual, 1) in (6, 7), 1, 0)     as is_weekend,
    if(date_actual = toLastDayOfMonth(date_actual), 1, 0) as is_month_end,
    if(
        date_actual = toLastDayOfMonth(date_actual)
        and toMonth(date_actual) in (3, 6, 9, 12),
        1, 0
    )                                                   as is_quarter_end,
    if(toMonth(date_actual) = 12 and toDayOfMonth(date_actual) = 31, 1, 0) as is_year_end,
    multiIf(
        toMonth(date_actual) in (12, 1, 2), 'Зима',
        toMonth(date_actual) in (3, 4, 5), 'Весна',
        toMonth(date_actual) in (6, 7, 8), 'Лето',
        toMonth(date_actual) in (9, 10, 11), 'Осень',
        ''
    )                                                   as season,
    if(toMonth(date_actual) <= 6, 1, 2)                 as half_year,
    toDayOfYear(date_actual)                             as ytd_day_number,
    toUnixTimestamp(now())                               as _loaded_at_ts
from date_spine
