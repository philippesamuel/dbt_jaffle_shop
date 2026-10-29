{%- set payment_methods = ['bank_transfer', 'coupon', 'credit_card', 'gift_card'] -%}

with payments as (

    select * from {{ ref('stg_stripe__payments') }}
    where payment_status = 'success'

),

final as (
    select
        to_char(created_at, 'yyyy-mm') as year_month,

        {% for method in payment_methods -%}
        sum(case when payment_method = '{{method}}' then payment_amount else 0 end) as {{method}}_payments,
        {% endfor %}
        count(order_id) as orders_count,
        min(payment_amount) as min_payment_amount,
        max(payment_amount) as max_payment_amount,
        avg(payment_amount) as mean_payment_amount,
        median(payment_amount) as median_payment_amount,
        sum(payment_amount) as total_payments

    from payments
    group by 1
    order by 1
)

select * from final