---Total revenue (USD)
select round(sum(price_usd), 0) as revenue_usd
from marts.fct_order_items
where order_status not in ('canceled', 'unavailable');

---Repeat customer %
select round(100.0 * avg(case when is_repeat_customer then 1 else 0 end), 1) as repeat_customer_pct
from marts.dim_customers;

---On-time delivery %
with orders as (
    select distinct order_id, is_late
    from marts.fct_order_items
    where order_status = 'delivered' and is_late is not null
)
select round(100.0 * avg(case when is_late then 0 else 1 end), 1) as on_time_pct
from orders;

---Monthly revenue trend
select
    d.year_month,
    round(sum(f.price_usd), 0) as revenue_usd
from marts.fct_order_items f
join marts.dim_date d on d.date_day = f.purchase_date
where f.order_status not in ('canceled', 'unavailable')
  and d.year_month between '2017-01' and '2018-08'
group by 1
order by 1;

---Top 10 categories by revenue
select
    p.category_name,
    round(sum(f.price_usd), 0) as revenue_usd
from marts.fct_order_items f
join marts.dim_products p on p.product_id = f.product_id
where f.order_status not in ('canceled', 'unavailable')
group by 1
order by 2 desc
limit 10;

---Late-delivery rate by customer state
with orders as (
    select distinct order_id, customer_unique_id, is_late
    from marts.fct_order_items
    where order_status = 'delivered' and is_late is not null
)
select
    c.state,
    round(100.0 * avg(case when o.is_late then 1 else 0 end), 1) as late_pct,
    count(*) as delivered_orders
from orders o
join marts.dim_customers c on c.customer_unique_id = o.customer_unique_id
group by 1
having count(*) >= 100
order by late_pct desc;

---Does late delivery hurt reviews?
with orders as (
    select distinct order_id, is_late, review_score
    from marts.fct_order_items
    where order_status = 'delivered'
      and is_late is not null
      and review_score is not null
)
select
    case when is_late then 'Late' else 'On time' end as delivery,
    round(avg(review_score), 2) as avg_review_score,
    count(*) as orders
from orders
group by 1
order by 1;

---Average order value and repeat rate by state
with order_totals as (
    select order_id, customer_unique_id, sum(price_usd) as order_usd
    from marts.fct_order_items
    where order_status not in ('canceled', 'unavailable')
    group by 1, 2
),
state_orders as (
    select
        c.state,
        count(*) as orders,
        round(avg(t.order_usd), 2) as avg_order_value_usd
    from order_totals t
    join marts.dim_customers c on c.customer_unique_id = t.customer_unique_id
    group by 1
),
state_customers as (
    select
        state,
        count(*) as customers,
        round(100.0 * avg(case when is_repeat_customer then 1 else 0 end), 1) as repeat_customer_pct
    from marts.dim_customers
    group by 1
)
select
    o.state,
    o.orders,
    c.customers,
    o.avg_order_value_usd,
    c.repeat_customer_pct
from state_orders o
join state_customers c on c.state = o.state
where o.orders >= 100
order by o.orders desc;