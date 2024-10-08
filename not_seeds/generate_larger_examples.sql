-- duckdb -c ".read ./not_seeds/generate_larger_examples.sql"
-- 10 million plus 20 million is 7 seconds
-- 100 million plus 200 million is 2 minutes 20 seconds on 0.10
-- 100 million plus 200 million is 1 minute on 1.1.0

--what about parquet?? Bet we can make this faaaaaast
-- 100 million plus 200 million is 38 seconds on 1.1.0 with parquet


COPY (
    from range(1000000) t(id)
    select 
        id,
        md5((id+1)::varchar) as first_name,
        md5((id+2)::varchar) as last_name
    order by 
        id
) TO '/Users/alex/Documents/DuckDB/jaffle_shop_duckdb/not_seeds/raw_customers.parquet' (compression 'ZSTD');


-- id,user_id,order_date,status
-- 1,1,2018-01-01,returned
-- 2,3,2018-01-02,completed
-- 3,94,2018-01-04,completed
-- returned,completed,return_pending,shipped,placed
COPY (
    with orders_without_ids as (
        from '/Users/alex/Documents/DuckDB/jaffle_shop_duckdb/not_seeds/raw_customers.parquet' customers 
        cross join range(100) t(id)
        select 
            customers.id as user_id,
            ('2024-01-01'::date + (interval 1 day * (random()*100)::int))::date as order_date,
            case when random() < 0.2 then 'returned' 
                when random() < 0.4 then 'completed' 
                when random() < 0.6 then 'return_pending' 
                when random() < 0.8 then 'shipped' 
                else 'placed'
            end as status
    )
    from orders_without_ids
    select 
        row_number() over (order by order_date, user_id) as id,
        user_id,
        order_date,
        status
) TO '/Users/alex/Documents/DuckDB/jaffle_shop_duckdb/not_seeds/raw_orders.parquet' (compression 'ZSTD');


-- id,order_id,payment_method,amount

--credit_card,coupon,bank_transfer,gift_card
COPY (
    from '/Users/alex/Documents/DuckDB/jaffle_shop_duckdb/not_seeds/raw_orders.parquet' orders 
    cross join range(2) t(payment_count)
    select 
        row_number() over (order by orders.id) as id,
        orders.id as order_id,
        case when random() < 0.25 then 'credit_card' 
            when random() < 0.5 then 'bank_transfer' 
            when random() < 0.75 then 'coupon' 
            else 'gift_card'
        end as payment_method,
        (random()*1000)::int as amount
) TO '/Users/alex/Documents/DuckDB/jaffle_shop_duckdb/not_seeds/raw_payments.parquet' (compression 'ZSTD')