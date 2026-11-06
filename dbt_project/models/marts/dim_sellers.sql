select
    seller_id,
    city,
    state,
    zip_code_prefix
from {{ ref('stg_olist__sellers') }}