{% macro deduplicate(source_ref, pk_col, order_col='_ingested_at') %}
select * from (
    select *,
           row_number() over (partition by {{ pk_col }} order by {{ order_col }} desc) as rn
    from {{ source_ref }}
) where rn = 1
{% endmacro %}


{% macro safe_divide(numerator, denominator) %}
    round({{ numerator }} / nullIf({{ denominator }}, 0), 2)
{% endmacro %}


{% macro mergetree_config(order_by, partition_by=none) %}
    {% if partition_by %}
        engine = MergeTree()
        order_by = {{ order_by }}
        partition_by = {{ partition_by }}
    {% else %}
        engine = MergeTree()
        order_by = {{ order_by }}
    {% endif %}
{% endmacro %}


{% macro last_day_of_month(date_col) %}
    toLastDayOfMonth({{ date_col }})
{% endmacro %}
