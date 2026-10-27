with

orders as (

    select * from {{ ref('stg_jaffle_shop__orders') }}

),

payments as (    

    select * from {{ ref('stg_stripe__payments') }}
    where payment_status <> 'fail'

),

order_totals as (

    select 
        order_id,
        payment_status,
        max(created_at) as payment_finalized_date, 
        sum(payment_amount) as total_amount_paid
    from payments
    group by order_id, payment_status

),

order_values_joined as (
    
    select
        orders.*,
        order_totals.payment_status,
        order_totals.payment_finalized_date,
        order_totals.total_amount_paid
    from orders
    left join order_totals on (orders.order_id = order_totals.order_id)

)

select * from order_values_joined
