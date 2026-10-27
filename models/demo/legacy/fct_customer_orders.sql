{% set customer_window %}
    partition by paid_orders.customer_id
    order by paid_orders.order_date, paid_orders.order_id
{% endset %}

with 

customers as (

    select * from {{ ref('stg_jaffle_shop__customers') }}

),
paid_orders as (

    select * from {{ ref('int_orders') }}

),

customer_orders as (

    select
        paid_orders.*,
        customers.customer_first_name,
        customers.customer_last_name,
        -- sales transaction sequence
        row_number() over (
            order by paid_orders.order_date, paid_orders.order_id
            ) as transaction_seq,
        
        -- customer sales sequence
        row_number() over ({{ customer_window }}) as customer_sales_seq,

        -- cumulative sum spent by customer (i.e. customer's lifetime value)
        sum(paid_orders.total_amount_paid) over ({{ customer_window }}) as customer_lifetime_value,
        
        -- first day of sale
        first_value(paid_orders.order_date) over ({{ customer_window }}) as fdos
    from paid_orders
    inner join customers on (paid_orders.customer_id = customers.customer_id)

),

final as (

    select
        order_id,
        customer_id,
        order_date as order_placed_at,
        order_status,
        total_amount_paid,
        payment_finalized_date,

        customer_first_name,
        customer_last_name,

        transaction_seq,
        customer_sales_seq,

        -- new or returning customer?
        case when customer_sales_seq = 1 
            then 'new' 
            else 'return' 
        end as nvsr,

        customer_lifetime_value,
        fdos
    from customer_orders

)

select * from final
