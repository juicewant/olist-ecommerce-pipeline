select
    product_category_name as category_name_pt,
    product_category_name_english as category_name_en
from {{ source('raw', 'product_category_translation') }}