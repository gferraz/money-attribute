# frozen_string_literal: true

class SimpleOffer < ApplicationRecord
  money_amount :price
  money_amount :discount
end
