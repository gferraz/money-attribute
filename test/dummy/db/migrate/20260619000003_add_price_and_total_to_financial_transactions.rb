class AddPriceAndTotalToFinancialTransactions < ActiveRecord::Migration[8.1]
  def change
    add_money_attribute :financial_transactions, :price
    add_money_attribute :financial_transactions, :total, currency: { column: :currency_code }
  end
end
