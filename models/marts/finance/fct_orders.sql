{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge'
    )
}}
with orders as (
    select * from {{ ref('stg_jaffle_shop__orders') }}
),

payments as (
    select * from {{ ref('stg_stripe__payments') }}
),

order_payments as (
    select
        order_id,
        sum(payment_amount) as total_order_amount
    from payments
    where payment_status = 'success'
    group by 1
),

final as (
    select
        o.order_id,
        o.customer_id,
        o.order_date,
        coalesce(p.total_order_amount, 0) as total_order_amount,
        o.updated_at
    from orders as o
    left join order_payments as p on (o.order_id = p.order_id)
)

select 
    * 
from final

{% if is_incremental() %}

where updated_at >= (select max(updated_at) from {{ this }} )

{% endif %}
