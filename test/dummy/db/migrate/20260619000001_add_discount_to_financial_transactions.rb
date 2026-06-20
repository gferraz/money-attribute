class AddDiscountToFinancialTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :financial_transactions, :discount, :integer
    add_column :financial_transactions, :discount_currency, :string, limit: 3
  end
end
