select
      id as payment_id
    , order_id
    , payment_method
    , status as payment_status
    , amount
    , created
    , _batched_at 
from raw.stripe.payments;