select
      id as payment_id
    , order_id
    , payment_method
    , status
    , amount / 100 as amount
    , created as created_at
from {{ source('stripe', 'payments') }}