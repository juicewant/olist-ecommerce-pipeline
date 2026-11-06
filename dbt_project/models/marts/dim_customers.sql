with orders_by_customer as (
    select
        c.customer_unique_id,
        c.city,
        c.state,
        c.zip_code_prefix,
        o.order_id,
        o.purchased_at
    from {{ ref('stg_olist__customers') }} c
    join {{ ref('stg_olist__orders') }} o
        on o.customer_id = c.customer_id
),

order_stats as (
    select
        customer_unique_id,
        count(distinct order_id) as lifetime_orders,
        min(purchased_at) as first_order_at,
        max(purchased_at) as last_order_at
    from orders_by_customer
    group by 1
),

latest_location as (
    select customer_unique_id, city, state, zip_code_prefix
    from orders_by_customer
    qualify row_number() over (
        partition by customer_unique_id
        order by purchased_at desc, order_id
    ) = 1
)

select
    l.customer_unique_id,
    l.city,
    l.state,
    l.zip_code_prefix,
    s.lifetime_orders,
    s.first_order_at,
    s.last_order_at,
    s.lifetime_orders > 1 as is_repeat_customer
from latest_location l
join order_stats s using (customer_unique_id)