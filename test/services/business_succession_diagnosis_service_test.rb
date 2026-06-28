# frozen_string_literal: true

require "test_helper"

class BusinessSuccessionDiagnosisServiceTest < ActiveSupport::TestCase
  def base_params(overrides = {})
    {
      president_age: "50",
      successor_status: "yes",
      sales: "10,000",
      operating_profit: "500",
      net_assets: "3,000",
      debt: "0",
      real_estate_value: "5,000",
      other_assets: "0",
      has_spouse: "1",
      count_heir_children: "1",
      spouse_acquisition_rate: "50",
      cash_assets: "10,000",
      company_value: "500"
    }.merge(overrides)
  end

  test "scores include baseline and are not zero unless zero conditions are met" do
    diagnosis = BusinessSuccessionDiagnosisService.new(base_params(company_value: "5,000")).call

    assert diagnosis.stock_risk_score >= BusinessSuccessionDiagnosisService::DEFAULT_MIN_RISK_SCORE
    assert diagnosis.overall_risk_score.positive?
  end

  test "zero score is allowed only when company value is 1000 man yen or less and cash covers tax five times" do
    diagnosis = BusinessSuccessionDiagnosisService.new(
      base_params(
        company_value: "500",
        cash_assets: "50,000",
        real_estate_value: "0",
        other_assets: "0",
        operating_profit: "0"
      )
    ).call

    assert_equal 0, diagnosis.stock_risk_score
    assert_equal 0, diagnosis.tax_funding_risk_score
  end

  test "zero score is not allowed when company value exceeds 1000 man yen" do
    diagnosis = BusinessSuccessionDiagnosisService.new(
      base_params(
        company_value: "1,500",
        cash_assets: "50,000"
      )
    ).call

    assert diagnosis.stock_risk_score >= BusinessSuccessionDiagnosisService::DEFAULT_MIN_RISK_SCORE
  end

  test "zero score is not allowed when cash is less than five times inheritance tax" do
    diagnosis = BusinessSuccessionDiagnosisService.new(
      base_params(
        company_value: "500",
        cash_assets: "100",
        real_estate_value: "20,000",
        other_assets: "0"
      )
    ).call

    assert diagnosis.estimated_inheritance_tax.positive?
    assert diagnosis.cash_assets < diagnosis.estimated_inheritance_tax * 5
    assert diagnosis.tax_funding_risk_score >= BusinessSuccessionDiagnosisService::DEFAULT_MIN_RISK_SCORE
  end
end
