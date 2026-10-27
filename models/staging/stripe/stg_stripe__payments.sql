with raw as (
      
    select * from {{ source('stripe', 'payments') }}
),

transformed as (
    select
        id as payment_id, 
        order_id, 
        payment_method, 
        status as payment_status,
        -- amount stored in cents, convert to dollars
        round(amount / 100.0, 2) as payment_amount, 
        created as created_at
    from raw
)

select * from transformed
