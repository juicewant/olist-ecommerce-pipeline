select
    rate_date,
    rate as brl_to_usd
from {{ source('raw', 'fx_rates') }}
where base_currency = 'BRL'
  and quote_currency = 'USD'
qualify row_number() over (partition by rate_date order by _loaded_at) = 1