select
    order_id,
    try_cast(payment_sequential as integer) as payment_sequential,
    payment_type,
    try_cast(payment_installments as integer) as payment_installments,
    try_cast(payment_value as decimal(10, 2)) as payment_value
from {{ source('raw', 'olist_order_payments') }}