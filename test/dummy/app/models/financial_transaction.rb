class FinancialTransaction < ApplicationRecord
  money_attribute :value, mapping: {amount: :amount, currency: :currency}
end
