class CreateSimilarIndustries < ActiveRecord::Migration[6.1]
  def change
    create_table :similar_industries do |t|
      t.integer :year, null: false
      t.string :industry_number, null: false
      t.string :major_category
      t.string :middle_category
      t.string :small_category
      t.string :industry_name, null: false
      t.decimal :stock_price_a_average, precision: 12, scale: 2, null: false
      t.decimal :dividend_b, precision: 12, scale: 4, null: false, default: 0
      t.decimal :profit_c, precision: 12, scale: 4, null: false, default: 0
      t.decimal :net_asset_d, precision: 12, scale: 4, null: false, default: 0
      t.string :source_url

      t.timestamps
    end

    add_index :similar_industries, [:year, :industry_number], unique: true, name: "index_similar_industries_on_year_and_number"
  end
end
