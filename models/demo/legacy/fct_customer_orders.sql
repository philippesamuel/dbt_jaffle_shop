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
    -- new or a returning customer?
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
    -- calculate first day of sale
    min(orders.order_date) over (
        partition by orders.customer_id
    ) as fdos
from orders
),

payments_per_order as (
select 
    order_id,
    max(created_at) as payment_finalized_date, 
    sum(payment_amount) as total_amount_paid
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

    -- cumulative sum spent by customer (i.e. customer's lifetime value)
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
    order_id,
    customer_id,
    order_date,
    order_status,
    total_amount_paid,
    payment_finalized_date,
    transaction_seq,
    customer_sales_seq,
    nvsr,
    fdos,
    customer_first_name,
    customer_last_name,
    customer_lifetime_value  
from paid_orders
)

select * from final
