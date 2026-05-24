# frozen_string_literal: true

# Simulations::StockValuationController と名前が衝突するため、Service を明示的に読み込む
Rails.application.config.to_prepare do
  Dir[Rails.root.join("app/services/stock_valuation/*.rb")].sort.each do |path|
    require_dependency path
  end
end
