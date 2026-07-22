class CreateSimpleOffers < ActiveRecord::Migration[7.1]
  def change
    create_table :simple_offers do |t|
      t.string :product
      t.date :date
      t.money_amount :price
      t.money_amount :discount

      t.timestamps
    end
  end
end
