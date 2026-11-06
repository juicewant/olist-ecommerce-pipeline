select
    date_day,
    extract(year from date_day) as year,
    extract(month from date_day) as month,
    strftime(date_day, '%B') as month_name,
    extract(quarter from date_day) as quarter,
    strftime(date_day, '%Y-%m') as year_month,
    strftime(date_day, '%A') as day_name
from {{ ref('int_date_spine') }}