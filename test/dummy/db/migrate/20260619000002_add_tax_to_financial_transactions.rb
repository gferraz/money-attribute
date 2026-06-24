class AddTaxToFinancialTransactions < ActiveRecord::Migration[8.1]
  def change
    add_money_attribute :financial_transactions, :tax, amount: { type: :bigint }, currency: false
  end
end
