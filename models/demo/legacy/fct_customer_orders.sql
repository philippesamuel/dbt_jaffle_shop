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

-- self join to calculate cumulative spent per order
x as (
select
    paid_orders.order_id,
    sum(t2.total_amount_paid) as clv_bad
from paid_orders
left join paid_orders as t2 
    on (paid_orders.customer_id = t2.customer_id 
        and paid_orders.order_id >= t2.order_id)
group by 1
order by paid_orders.order_id
),

customer_orders as (
select 
    customers.id as customer_id, 
    min(orders.order_date) as first_order_date, 
    max(orders.order_date) as most_recent_order_date, 
    count(orders.id) as number_of_orders
from raw_customers as customers
left join raw_orders as orders on (orders.user_id = customers.id)
group by 1    
),

final as (
select
    paid_orders.*,
    row_number() over (order by paid_orders.order_id) as transaction_seq,
    row_number() over (partition by paid_orders.customer_id order by paid_orders.order_id) as customer_sales_seq,
    (
        case when customer_orders.first_order_date = paid_orders.order_placed_at
            then 'new'
            else 'return' 
        end
    ) as nvsr,
    x.clv_bad as customer_lifetime_value,
    customer_orders.first_order_date as fdos
from paid_orders
left join customer_orders using (customer_id)
left outer join x on (x.order_id = paid_orders.order_id)
order by order_id
)

select * from final
