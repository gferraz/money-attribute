class CreateOffers < ActiveRecord::Migration[7.1]
  def change
    create_table :offers do |t|
      t.string :product
      t.date :date
      t.money_attribute :price

      t.timestamps
    end
  end
end
