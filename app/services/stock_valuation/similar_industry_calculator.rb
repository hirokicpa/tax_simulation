# frozen_string_literal: true

module StockValuation
  # 財産評価基本通達180・183に基づく類似業種比準価額の計算
  # A × ((Ⓑ/B + Ⓒ/C + Ⓓ/D) / n) × 斟酌率 × (1株当たりの資本金等の額 / 50円)
  class SimilarIndustryCalculator
    CAPITAL_BASIS_YEN = 50

    ELEMENTS = {
      dividend: { label: "配当", company_key: :per_share_dividend, industry_attr: :dividend_b },
      profit: { label: "利益", company_key: :per_share_profit, industry_attr: :profit_c },
      net_asset: { label: "純資産", company_key: :per_share_net_asset, industry_attr: :net_asset_d }
    }.freeze

    Result = Struct.new(
      :per_share_capital,
      :capital_multiplier,
      :per_share_dividend,
      :per_share_profit,
      :per_share_net_asset,
      :element_ratios,
      :comparison_ratio,
      :discretion_rate,
      :per_share_valuation_on_capital_basis,
      :per_share_valuation,
      :total_valuation,
      :warnings,
      :calculation_steps,
      keyword_init: true
    )

    def initialize(
      capital_amount:,
      issued_shares:,
      annual_dividend:,
      annual_profit:,
      net_assets:,
      industry:,
      company_size:
    )
      @capital_amount = capital_amount.to_i
      @issued_shares = issued_shares.to_i
      @annual_dividend = annual_dividend.to_i
      @annual_profit = annual_profit.to_i
      @net_assets = net_assets.to_i
      @industry = industry
      @company_size = company_size
    end

    def call
      warnings = []
      steps = []

      per_share_capital = (@capital_amount.to_f / @issued_shares).round(4)
      capital_multiplier = (per_share_capital / CAPITAL_BASIS_YEN).round(6)

      per_share_dividend = on_capital_basis(per_share(@annual_dividend), per_share_capital)
      per_share_profit = on_capital_basis(per_share(@annual_profit), per_share_capital)
      per_share_net_asset = on_capital_basis(per_share(@net_assets), per_share_capital)

      steps << "1株当たりの資本金等の額 = #{yen(@capital_amount)} ÷ #{@issued_shares}株 = #{yen(per_share_capital, precision: 4)}"
      steps << "評価会社のⒷ（配当・50円換算）= #{yen(per_share(@annual_dividend), precision: 4)} × 50円 ÷ #{yen(per_share_capital, precision: 4)} = #{yen(per_share_dividend, precision: 4)}"
      steps << "評価会社のⒸ（利益・50円換算）= #{yen(per_share(@annual_profit), precision: 4)} × 50円 ÷ #{yen(per_share_capital, precision: 4)} = #{yen(per_share_profit, precision: 4)}"
      steps << "評価会社のⒹ（純資産・50円換算）= #{yen(per_share(@net_assets), precision: 4)} × 50円 ÷ #{yen(per_share_capital, precision: 4)} = #{yen(per_share_net_asset, precision: 4)}"

      company_values = {
        dividend: per_share_dividend,
        profit: per_share_profit,
        net_asset: per_share_net_asset
      }

      element_ratios = {}
      ratio_terms = []

      ELEMENTS.each do |key, config|
        industry_value = @industry.public_send(config[:industry_attr]).to_f
        company_value = company_values.fetch(key)

        if industry_value <= 0
          warnings << "類似業種の#{config[:label]}（B/C/D）が0以下のため、#{config[:label]}要素は比準割合から除外します。"
          next
        end

        ratio = if company_value.negative?
                  warnings << "評価会社の#{config[:label]}がマイナスのため、#{config[:label]}比準割合は0として計算します。"
                  0.0
                else
                  company_value / industry_value
                end

        element_ratios[key] = ratio
        ratio_terms << ratio
        steps << "#{config[:label]}比準割合（Ⓑ/B等）= #{company_value.round(4)} ÷ #{industry_value} = #{ratio.round(4)}"
      end

      comparison_ratio = if ratio_terms.empty?
                           warnings << "比準要素が1つも算出できないため、比準割合を0として計算します。"
                           0.0
                         else
                           ratio_terms.sum / ratio_terms.size.to_f
                         end

      discretion_rate = @company_size.discretion_rate
      stock_price_a = @industry.prior_year_average_stock_price

      per_share_valuation_on_capital_basis =
        (stock_price_a * comparison_ratio * discretion_rate).floor
      per_share_valuation = (per_share_valuation_on_capital_basis * capital_multiplier).floor
      total_valuation = per_share_valuation * @issued_shares

      ratio_sum_label = ratio_terms.map { |v| v.round(4) }.join(" + ")
      steps << "比準割合 = (#{ratio_sum_label}) ÷ #{ratio_terms.size} = #{comparison_ratio.round(4)}"
      steps << "類似業種株価 A（前年平均株価）= #{yen(stock_price_a)}"
      steps << "類似業種比準価額（50円換算）= A × 比準割合(#{comparison_ratio.round(4)}) × 斟酌率(#{discretion_rate}) = #{yen(per_share_valuation_on_capital_basis)}"
      if (capital_multiplier - 1.0).abs > 0.000_001
        steps << "資本金等の調整 = #{yen(per_share_valuation_on_capital_basis)} × (#{per_share_capital.round(4)}円 ÷ 50円) = #{yen(per_share_valuation)}"
      end
      steps << "株式全体の評価額 = #{yen(per_share_valuation)} × #{@issued_shares}株 = #{yen(total_valuation)}"

      Result.new(
        per_share_capital: per_share_capital,
        capital_multiplier: capital_multiplier,
        per_share_dividend: per_share_dividend,
        per_share_profit: per_share_profit,
        per_share_net_asset: per_share_net_asset,
        element_ratios: element_ratios,
        comparison_ratio: comparison_ratio,
        discretion_rate: discretion_rate,
        per_share_valuation_on_capital_basis: per_share_valuation_on_capital_basis,
        per_share_valuation: per_share_valuation,
        total_valuation: total_valuation,
        warnings: warnings,
        calculation_steps: steps
      )
    end

    private

    def on_capital_basis(actual_per_share, per_share_capital)
      return 0.0 if per_share_capital.zero?

      (actual_per_share * CAPITAL_BASIS_YEN / per_share_capital).round(4)
    end

    def per_share(amount)
      (amount.to_f / @issued_shares).round(4)
    end

    def yen(value, precision: 0)
      ActiveSupport::NumberHelper.number_to_delimited(value.round(precision))
    end
  end
end
