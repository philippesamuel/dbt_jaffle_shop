-- several payments can be performed regarding the same order_id (think 'refunds')
-- therefore the total amount for a given order must be >= 0.
select
    order_id
    , sum(amount) as total_amount
from {{ ref('stg_stripe__payments') }}
group by 1
having total_amount < 0
