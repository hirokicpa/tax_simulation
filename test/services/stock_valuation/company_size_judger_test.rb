# frozen_string_literal: true

require "test_helper"

class StockValuation::CompanySizeJudgerTest < ActiveSupport::TestCase
  test "70人以上は大会社" do
    result = StockValuation::CompanySizeJudger.new(
      total_assets: 1_000_000,
      annual_sales: 1_000_000,
      employees: 70,
      industry_type: "other"
    ).call

    assert_equal :large, result.size_code
    assert_equal "大会社", result.size_label
    assert_nil result.l_ratio
    assert_in_delta 0.7, result.discretion_rate
  end

  test "卸売業で資産・取引が大会社基準かつ従業員36人以上" do
    result = StockValuation::CompanySizeJudger.new(
      total_assets: 25_000_000_000,
      annual_sales: 35_000_000_000,
      employees: 40,
      industry_type: "wholesale"
    ).call

    assert_equal :large, result.size_code
    assert_equal "大会社", result.size_label
  end

  test "卸売業で従業員35人以下は資産・取引が大会社基準でも大会社にならない" do
    result = StockValuation::CompanySizeJudger.new(
      total_assets: 25_000_000_000,
      annual_sales: 35_000_000_000,
      employees: 35,
      industry_type: "wholesale"
    ).call

    assert_not_equal :large, result.size_code
  end

  test "卸売業で小会社" do
    result = StockValuation::CompanySizeJudger.new(
      total_assets: 50_000_000,
      annual_sales: 100_000_000,
      employees: 3,
      industry_type: "wholesale"
    ).call

    assert_equal :small, result.size_code
    assert_equal "小会社", result.size_label
    assert_in_delta 0.5, result.discretion_rate
  end

  test "卸売業で中会社" do
    result = StockValuation::CompanySizeJudger.new(
      total_assets: 8_000_000_000,
      annual_sales: 1_000_000_000,
      employees: 10,
      industry_type: "wholesale"
    ).call

    assert_equal :medium, result.size_code
    assert_equal "中会社", result.size_label
    assert_in_delta 0.9, result.l_ratio
    assert_in_delta 0.6, result.discretion_rate
  end

  test "卸売業・小売・サービス業以外で取引15億円ちょうどはL0.90" do
    result = StockValuation::CompanySizeJudger.new(
      total_assets: 10_000_000_000,
      annual_sales: 1_500_000_000,
      employees: 10,
      industry_type: "other"
    ).call

    assert_equal :medium, result.size_code
    assert_in_delta 0.9, result.l_ratio
  end

  test "卸売業・小売・サービス業以外で取引15億円超は取引によるLは付かない" do
    result = StockValuation::CompanySizeJudger.new(
      total_assets: 40_000_000,
      annual_sales: 1_500_000_001,
      employees: 5,
      industry_type: "other"
    ).call

    assert_equal :medium, result.size_code
    assert_in_delta 0.0, result.l_ratio
  end

  test "小売・サービス業で大会社は取引20億円以上" do
    result = StockValuation::CompanySizeJudger.new(
      total_assets: 16_000_000_000,
      annual_sales: 21_000_000_000,
      employees: 40,
      industry_type: "retail_service"
    ).call

    assert_equal :large, result.size_code
  end
end
