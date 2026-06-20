class FinancialTransaction < ApplicationRecord
  money_attribute :amount
  money_attribute :discount
  money_attribute :tax
end
