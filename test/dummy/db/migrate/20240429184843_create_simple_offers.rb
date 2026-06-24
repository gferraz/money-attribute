class CreateSimpleOffers < ActiveRecord::Migration[7.1]
  def change
    create_table :simple_offers do |t|
      t.string :product
      t.date :date
      t.money_attribute :price, currency: false
      t.money_attribute :discount, currency: false

      t.timestamps
    end
  end
end
