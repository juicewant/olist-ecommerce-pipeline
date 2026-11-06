with latest_rate_date as (
    select
        c.date_day,
        max(f.rate_date) as rate_date
    from {{ ref('int_date_spine') }} c
    join {{ ref('stg_fx__rates') }} f
        on f.rate_date <= c.date_day
    group by 1
)

select
    l.date_day,
    f.brl_to_usd
from latest_rate_date l
join {{ ref('stg_fx__rates') }} f
    on f.rate_date = l.rate_date