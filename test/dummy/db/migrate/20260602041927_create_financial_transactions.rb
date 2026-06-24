class CreateFinancialTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :financial_transactions do |t|
      t.string :description
      t.datetime :date
      t.money_attribute :amount, amount: { type: :integer }, currency: { limit: 3 }

      t.timestamps
    end
  end
end
