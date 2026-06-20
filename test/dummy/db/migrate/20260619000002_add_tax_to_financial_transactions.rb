class AddTaxToFinancialTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :financial_transactions, :tax, :bigint
  end
end
