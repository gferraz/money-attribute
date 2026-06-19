class FinancialTransaction < ApplicationRecord
  money_attribute :amount, mapping: {amount: :amount, currency: :currency}
end
