-- Is it possible to force the usage to require parameter_name=parameter_value?

{{ config(
    materialized="view",
    pre_hook= "{{ sort_in_chunks('orders_unsorted', 'orders_sorted', {'status': 'desc', 'order_date': 'desc'}, {'customer_id': 'desc', 'order_id': 'asc'}) }}"
)}}

-- depends_on: {{ ref('orders_unsorted') }}
-- depends_on: {{ ref('orders_sorted') }}

select *
from {{ ref( 'orders_sorted' ) }}