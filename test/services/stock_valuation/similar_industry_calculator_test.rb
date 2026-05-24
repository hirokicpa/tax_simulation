# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../../config/environment"

module StockValuation
  class SimilarIndustryCalculatorTest < Minitest::Test
    def setup
      @industry = SimilarIndustry.new(
        year: 2025,
        industry_number: "31",
        industry_name: "食料品製造業",
        stock_price_a_average: 500,
        dividend_b: 10,
        profit_c: 40,
        net_asset_d: 300
      )
      @company_size = CompanySizeJudger::Result.new(
        size_code: :large,
        size_label: "大会社",
        l_ratio: nil,
        discretion_rate: 0.7,
        industry_type_label: "その他",
        judgment_basis: ""
      )
    end

    def test_calculates_similar_industry_valuation_on_50_yen_capital_basis
      result = SimilarIndustryCalculator.new(
        capital_amount: 500_000,
        issued_shares: 10_000,
        annual_dividend: 50_000,
        annual_profit: 400_000,
        net_assets: 30_000_000,
        industry: @industry,
        company_size: @company_size
      ).call

      assert_in_delta 50.0, result.per_share_capital, 0.01
      assert_in_delta 1.0, result.capital_multiplier, 0.0001
      assert_in_delta 0.5, result.element_ratios[:dividend], 0.0001
      assert_in_delta 1.0, result.element_ratios[:profit], 0.0001
      assert_in_delta 10.0, result.element_ratios[:net_asset], 0.0001
      assert_in_delta 3.8333, result.comparison_ratio, 0.0001
      assert_equal 1341, result.per_share_valuation_on_capital_basis
      assert_equal 1341, result.per_share_valuation
      assert_equal 13_410_000, result.total_valuation
    end

    def test_applies_capital_multiplier_when_not_50_yen
      result = SimilarIndustryCalculator.new(
        capital_amount: 10_000_000,
        issued_shares: 10_000,
        annual_dividend: 50_000,
        annual_profit: 400_000,
        net_assets: 30_000_000,
        industry: @industry,
        company_size: @company_size
      ).call

      assert_in_delta 1000.0, result.per_share_capital, 0.01
      assert_in_delta 20.0, result.capital_multiplier, 0.01
      assert_in_delta 0.025, result.element_ratios[:dividend], 0.0001
      assert_equal 67, result.per_share_valuation_on_capital_basis
      assert_equal 1340, result.per_share_valuation
    end

    def test_comparison_ratio_may_exceed_one
      result = SimilarIndustryCalculator.new(
        capital_amount: 500_000,
        issued_shares: 10_000,
        annual_dividend: 50_000,
        annual_profit: 400_000,
        net_assets: 30_000_000,
        industry: @industry,
        company_size: @company_size
      ).call

      assert_operator result.element_ratios[:net_asset], :>, 1.0
      assert_operator result.comparison_ratio, :>, 1.0
    end
  end
end
