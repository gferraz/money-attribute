class CreateFinancialTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :financial_transactions do |t|
      t.string :description
      t.datetime :date
      t.integer :amount
      t.string :currency, limit: 3

      t.timestamps
    end
  end
end
