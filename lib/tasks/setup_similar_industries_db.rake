# frozen_string_literal: true

namespace :db do
  desc "similar_industries テーブルを作成し CSV を取込（マイグレーション未実行時の救済用）"
  task setup_similar_industries: :environment do
    unless ActiveRecord::Base.connection.table_exists?(:similar_industries)
      ActiveRecord::Base.connection.create_table :similar_industries do |t|
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
      ActiveRecord::Base.connection.add_index :similar_industries,
        [:year, :industry_number],
        unique: true,
        name: "index_similar_industries_on_year_and_number"
      puts "similar_industries テーブルを作成しました。"
    else
      puts "similar_industries テーブルは既に存在します。"
    end

    version = "20260509120000"
    unless ActiveRecord::Base.connection.select_value(
      "SELECT 1 FROM schema_migrations WHERE version = #{ActiveRecord::Base.connection.quote(version)}"
    )
      ActiveRecord::Base.connection.execute(
        "INSERT INTO schema_migrations (version) VALUES (#{ActiveRecord::Base.connection.quote(version)})"
      )
    end

    if SimilarIndustry.exists?
      puts "類似業種データは既に #{SimilarIndustry.count} 件あります。"
    else
      path = Rails.root.join("db/seed_data/similar_industries_r07.csv")
      if path.exist?
        Rake::Task["similar_industries:import"].invoke
      else
        puts "CSVがありません。`rails similar_industries:reimport_r07` を実行してください。"
      end
    end
  end
end
