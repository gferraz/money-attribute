class AddPriceAndTotalToFinancialTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :financial_transactions, :price_amount, :decimal
    add_column :financial_transactions, :price_currency, :string
    add_column :financial_transactions, :total_amount, :decimal
    add_column :financial_transactions, :currency_code, :string
  end
end
