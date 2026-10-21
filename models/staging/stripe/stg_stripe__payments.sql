select
      id as payment_id
    , order_id
    , payment_method
    , status as payment_status
    -- amount stored in cents, convert to dollars
    , amount / 100 as amount
    , created as created_at
from {{ source('stripe', 'payments') }}