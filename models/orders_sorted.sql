{{ config(
    materialized="view",
)}}

-- This is changed from a view to a table in the orders model using the sort_in_chunks macro
-- While the dbt DAG runs, this will return unsorted data. 
-- After the run, it will be a table of sorted data. 
select *
from {{ ref( 'orders_unsorted' ) }}