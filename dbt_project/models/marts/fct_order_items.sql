with items as (
    select * from {{ ref('stg_olist__order_items') }}
),

orders as (
    select * from {{ ref('stg_olist__orders') }}
),

customers as (
    select customer_id, customer_unique_id
    from {{ ref('stg_olist__customers') }}
),

reviews as (
    select order_id, review_score
    from {{ ref('stg_olist__order_reviews') }}
    qualify row_number() over (
        partition by order_id
        order by review_created_at desc, review_answered_at desc, review_id
    ) = 1
),

fx as (
    select date_day, brl_to_usd from {{ ref('int_fx_daily') }}
)

select
    i.order_id || '-' || cast(i.order_item_id as varchar) as order_item_key,
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    c.customer_unique_id,
    cast(o.purchased_at as date) as purchase_date,
    o.order_status,

    -- revenue (BRL and USD)
    i.price,
    i.freight_value,
    i.price + i.freight_value as item_total,
    fx.brl_to_usd as fx_rate,
    round(i.price * fx.brl_to_usd, 2) as price_usd,
    round((i.price + i.freight_value) * fx.brl_to_usd, 2) as item_total_usd,

    -- delivery performance
    o.purchased_at,
    o.delivered_at,
    o.estimated_delivery_at,
    {{ dbt.datediff('o.purchased_at', 'o.delivered_at', 'day') }} as delivery_days,
    {{ dbt.datediff('o.estimated_delivery_at', 'o.delivered_at', 'day') }} as days_vs_estimate,
    case
        when o.delivered_at is null then null
        else o.delivered_at > o.estimated_delivery_at
    end as is_late,

    -- customer satisfaction
    r.review_score
from items i
join orders o on o.order_id = i.order_id
join customers c on c.customer_id = o.customer_id
left join reviews r on r.order_id = i.order_id
left join fx on fx.date_day = cast(o.purchased_at as date)