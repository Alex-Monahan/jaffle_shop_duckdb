/*
This macro is used to sort a table in chunks when sorting all at once would take too much memory.
It will query the unsorted table (input_ref) once per partition, using a where clause to filter to that partition.
It will then sort that partition of data and insert into (output_ref). 

Note: Since this scans the input data once per partition, the recommendation is to use the fewest number
      of partitions needed for the sort to fit in memory / disk.
      It may be faster to partition so that the sort fits in memory alone - it depends!

Note: This will only work if the config preserve_insertion_order = true. 
      This is already the default on MotherDuck.
      (https://duckdb.org/docs/stable/configuration/overview.html)

To use this, 3 models are required:
* input_ref (unsorted table)
    * Typical / pre-existing logic for building the large table
    * Recommended to rename to a new name like old_name_unsorted
    * materialized as table ?

* output_ref (sorted table)
    * select * from {{ input_ref }}
    * materialized as view
    * NOTE: This will be converted to a table in this macro.
            It is included to prevent external / read queries from failing while the job runs
            and as a placeholder for dbt to understand lineage.

* model that the remainder of the DAG will depend on
    * Calls sort_in_chunks in a pre-hook
    * select * from {{ output_ref }}
    * Recommended to use the original old_name (so it fits into the DAG nicely)
    * materialized as view
    * Comments to indicate that it depends on input_ref and output_ref

Example of calling this macro:
pre_hook= "{{ sort_in_chunks(
    'table_unsorted',
    'table_sorted',
    {'partition_col_1': 'desc', 'partition_col_2': 'desc'},
    {'order_by_col_1': 'desc', 'order_by_col_2': 'asc'}
) }}"

Include dry_run set to true to log out the queries that would be run in the insert loop.


TODO: Convert SELECT * into the star expansion macro from dbt (so the logging includes all columns)
            {{ dbt_utils.star(ref('my_model')) }}

*/

{% macro sort_in_chunks(input_ref, output_ref, partition_columns_dict, order_columns_dict, dry_run='false') %}
    {%- if execute -%}
        {%- do log("Preparing to get partitions for: sort_in_chunks" , info=True) -%}
        {% set sql_statement %}
        SELECT DISTINCT 
            {% for partition_column, asc_desc in partition_columns_dict.items() %}
                {{ partition_column }}
                {%- if not loop.last  -%}, {%- endif -%}
            {% endfor %}
        FROM {{ ref(input_ref) }} 
        ORDER BY 
            {% for partition_column, asc_desc in partition_columns_dict.items() %}
                {{ partition_column }} {{ asc_desc }}
                {%- if not loop.last  -%}, {%- endif -%}
            {% endfor %}
        {% endset %}
        {% do log(sql_statement) %}

        {%- do log("Getting partitions for: sort_in_chunks" , info=True) -%}
        {%- set target = run_query(sql_statement) -%}

        {%- do log("Convert placeholder view of input_ref into a table" , info=True) -%}
        {% set view_to_table %}
            DROP VIEW IF EXISTS {{ ref(output_ref) }};
            CREATE OR REPLACE TABLE {{ ref(output_ref) }} AS 
                SELECT {{ dbt_utils.star(ref(input_ref)) }}
                FROM {{ ref(input_ref) }} 
                LIMIT 0;
        {% endset %}
        {% do log(view_to_table) %}

        {% if dry_run == 'false' %} {% do run_query(view_to_table) %} {% endif %}

        {%- do log("Looping over each partition, sorting within partition, and inserting to output_ref." , info=True) -%}
        {% for i in target.rows -%}
            {% set copy_target %}
            INSERT INTO {{ ref(output_ref) }}
            SELECT {{ dbt_utils.star(ref(input_ref)) }}
            FROM {{ ref(input_ref) }}
            WHERE 1=1
                {% for partition_column, asc_desc in partition_columns_dict.items() %}
                    AND {{ partition_column }} = '{{ i[loop.index - 1] | replace("'", "''") }}' -- to fix syntax highlighting:" 
                {% endfor %}      
            ORDER BY 
                {% for order_column, asc_desc in order_columns_dict.items() %}
                    {{ order_column }} {{ asc_desc }}
                    {%- if not loop.last  -%}, {%- endif -%}
                {% endfor %}
            {% endset %}
            {%- do log("running query below...") -%}
            {% do log(copy_target, info=false) %}
            {% if dry_run == 'false' %} {% do run_query(copy_target) %} {% endif %}
            {% set copy_target = true %}
        {% endfor %}
        {% do log("copy completed for: sort_in_chunks", info=True) %}
    {% endif %}
{% endmacro %}