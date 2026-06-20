class FinancialTransaction < ApplicationRecord
  money_attribute :amount
  money_attribute :discount
end
