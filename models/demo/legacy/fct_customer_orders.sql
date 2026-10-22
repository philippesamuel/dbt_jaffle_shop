with 

raw_orders as (
    select * from {{ source('jaffle_shop', 'orders') }} 
),

raw_customers as (
    select * from {{ source('jaffle_shop', 'customers') }}
),

raw_payments as (    
    select * from {{ source('stripe', 'payments') }}
),

payments_per_order as (
select 
    payments.order_id as order_id, 
    max(payments.created) as payment_finalized_date, 
    sum(payments.amount) / 100.0 as total_amount_paid
from raw_payments as payments
where status <> 'fail'
group by 1
),

paid_orders as (
select 
    orders.id as order_id,
    orders.user_id as customer_id,
    orders.order_date as order_placed_at,
    orders.status as order_status,
    payments.total_amount_paid,
    payments.payment_finalized_date,
    raw_customers.first_name as customer_first_name,
    raw_customers.last_name as customer_last_name
from raw_orders as orders
left join payments_per_order as payments on (orders.id = payments.order_id)
left join raw_customers on (orders.user_id = raw_customers.id)
),

final as (
select
    paid_orders.*,
    row_number() over (order by paid_orders.order_id) as transaction_seq,
    row_number() over (partition by paid_orders.customer_id order by paid_orders.order_id) as customer_sales_seq,
    
    -- window function to detect whether an order is new or a return
    ( 
        case 
        when (
        rank() over (
            partition by paid_orders.customer_id
            order by paid_orders.order_placed_at, paid_orders.order_id
            ) = 1
        ) then 'new' else 'return' 
        end
    ) as nvsr,

    -- calculate cumulative sum spent by customer (i.e. customer's lifetime value)
    sum(paid_orders.total_amount_paid) over (
        partition by paid_orders.customer_id
        order by paid_orders.order_placed_at, paid_orders.order_id
    ) as customer_lifetime_value,
    
    -- calculate first order date for a specific order
    min(paid_orders.order_placed_at) over (
        partition by paid_orders.customer_id
    ) as fdos
from paid_orders
order by order_id
)

select * from final
