# frozen_string_literal: true

require "minitest/autorun"
require "bigdecimal"
require_relative "../../../config/environment"

module StockValuation
  class PdfSimilarIndustryParserTest < Minitest::Test
    def setup
      @parser = PdfSimilarIndustryParser.new(StringIO.new(""))
    end

    def test_extract_prior_year_stock_price_for_no30_line
      line = "金 属 製 品 製 造 業  30                         10.152 585 439 437 437"
      bcd = @parser.send(:extract_bcd_from_line, line)
      price = @parser.send(:extract_prior_year_stock_price, line, bcd)

      assert_equal 439.0, price
    end

    def test_extract_prior_year_stock_price_for_spaced_bcd_line
      line = "50 製造業のうち、10から49に該当するもの以       8.4 37 365  396  408  416"
      bcd = @parser.send(:extract_bcd_from_line, line)
      price = @parser.send(:extract_prior_year_stock_price, line, bcd)

      assert_equal 396.0, price
    end
  end
end
