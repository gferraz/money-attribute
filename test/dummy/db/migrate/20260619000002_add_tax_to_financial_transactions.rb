class AddTaxToFinancialTransactions < ActiveRecord::Migration[8.1]
  def change
    add_money_amount :financial_transactions, :tax, amount: { type: :bigint }
  end
end
