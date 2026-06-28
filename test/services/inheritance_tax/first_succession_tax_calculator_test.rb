# frozen_string_literal: true

require "test_helper"

class InheritanceTax::FirstSuccessionTaxCalculatorTest < ActiveSupport::TestCase
  test "配偶者と子2人・1次相続Aと同等の計算" do
    calc = InheritanceTax::FirstSuccessionTaxCalculator.new(
      total_heritage_man: 10_000,
      count_heir_children: 2,
      has_spouse: true,
      marital_rate: 0.0
    ).call

    assert_equal 4800, calc.basic_reduction_man
    assert_equal 5200, calc.taxable_price_man
    assert_equal 630, calc.tax_man
  end

  test "子のみ3人" do
    calc = InheritanceTax::FirstSuccessionTaxCalculator.new(
      total_heritage_man: 8000,
      count_heir_children: 3,
      has_spouse: false
    ).call

    assert_equal 4800, calc.basic_reduction_man
    assert_equal 3200, calc.taxable_price_man
    assert calc.tax_man.positive?
  end

  test "配偶者ありで取得割合0〜100%を試算できる" do
    rows = InheritanceTax::FirstSuccessionTaxCalculator.calculate_all_spouse_rates(
      total_heritage_man: 10_000,
      count_heir_children: 2,
      has_spouse: true
    )

    assert_equal 11, rows.size
    assert_equal "0%", rows.first.label
    assert_equal "100%", rows.last.label
    assert rows.first.tax_man >= rows.last.tax_man
  end
end
