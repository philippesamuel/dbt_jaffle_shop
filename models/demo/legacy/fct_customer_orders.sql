-- Import CTEs
with 
customers as (
    select * from {{ ref('stg_jaffle_shop__customers') }}
),
orders as (
    select * from {{ ref('stg_jaffle_shop__orders') }}
),
payments as (    
    select * from {{ ref('stg_stripe__payments') }}
),

-- Staging CTEs
orders_ranked as (
select
    orders.order_id,
    orders.customer_id,
    orders.order_date,
    orders.order_status,
    row_number() over (order by orders.order_id) as transaction_seq,
    row_number() over (partition by orders.customer_id order by orders.order_id) as customer_sales_seq,
    -- window function to detect whether an order is new or a return
    ( 
        case 
        when (
        rank() over (
            partition by orders.customer_id
            order by orders.order_date, orders.order_id
            ) = 1
        ) then 'new' else 'return' 
        end
    ) as nvsr,
    -- calculate first order date for a specific order
    min(orders.order_date) over (
        partition by orders.customer_id
    ) as fdos
from orders
),

payments_per_order as (
select 
    payments.order_id,
    max(payments.created_at) as payment_finalized_date, 
    sum(payments.amount) as total_amount_paid
from payments
where payment_status <> 'fail'
group by 1
),

-- Marts
paid_orders as (
select 
    orders_ranked.order_id,
    orders_ranked.customer_id,
    orders_ranked.order_date,
    orders_ranked.order_status,
    orders_ranked.transaction_seq,
    orders_ranked.customer_sales_seq,
    orders_ranked.nvsr,
    orders_ranked.fdos,

    payments.total_amount_paid,
    payments.payment_finalized_date,

    customers.customer_first_name,
    customers.customer_last_name,

    -- calculate cumulative sum spent by customer (i.e. customer's lifetime value)
    sum(payments.total_amount_paid) over (
        partition by orders_ranked.customer_id
        order by orders_ranked.order_date, orders_ranked.order_id
    ) as customer_lifetime_value
from orders_ranked
left join payments_per_order as payments on (orders_ranked.order_id = payments.order_id)
left join customers on (orders_ranked.customer_id = customers.customer_id)
),

-- Final CTE 
final as (
select
    paid_orders.order_id,
    paid_orders.customer_id,
    paid_orders.order_date,
    paid_orders.order_status,
    paid_orders.transaction_seq,
    paid_orders.customer_sales_seq,
    paid_orders.nvsr,
    paid_orders.fdos,
    paid_orders.total_amount_paid,
    paid_orders.payment_finalized_date,
    paid_orders.customer_first_name,
    paid_orders.customer_last_name,
    paid_orders.customer_lifetime_value  
from paid_orders
)

select * from final
