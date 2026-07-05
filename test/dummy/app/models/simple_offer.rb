class SimpleOffer < ApplicationRecord
  money_amount :price, currency: 'USD'
  money_amount :discount, currency: 'USD'
end
