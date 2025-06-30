{{ config(
    materialized="table",
)}}

select *
from {{ ref( 'orders_unsorted' ) }}
limit 0