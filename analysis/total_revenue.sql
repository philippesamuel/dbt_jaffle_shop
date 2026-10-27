with payments as (

    select * from {{ ref('stg_stripe__payments') }}
    where payment_status = 'success'

),

aggregated as (

    select 
        sum(payment_amount) as total_revenue
    from payments

)

select * from aggregated