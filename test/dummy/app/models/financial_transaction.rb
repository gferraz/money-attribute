class FinancialTransaction < ApplicationRecord
  money_attribute :amount
  money_attribute :discount
  money_attribute :price
  money_amount :tax
  money_attribute :total, mapping: { amount: :total_amount, currency: :currency_code }
end
