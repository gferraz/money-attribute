class AddDiscountToFinancialTransactions < ActiveRecord::Migration[8.1]
  def change
    add_money_attribute :financial_transactions, :discount, amount: { type: :fiat_integer }, currency: { limit: 3 }
  end
end
