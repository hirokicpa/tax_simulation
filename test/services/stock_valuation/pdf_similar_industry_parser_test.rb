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

    def test_no79_is_kakushu_shohin_not_footnote
      parser = PdfSimilarIndustryParser.new(StringIO.new(""))
      correct = "各 種 商 品 小 売 業    79 百貨店、総合スーパーマーケット、コンビ         8.6 67 524  713  682  684"
      footnote = "そ の 他 の 小 売 業 85 小売業(無店舗小売業を除く)のうち、79        8.9 53 340  578  584  615"

      bcd = parser.send(:extract_bcd_from_line, correct)
      num = parser.send(:extract_industry_number_before_bcd, correct, bcd[:position])
      name = SimilarIndustry.compact_industry_name(parser.send(:extract_name, correct, num))

      assert_equal "79", num
      assert_equal "各種商品小売業", name

      bcd85 = parser.send(:extract_bcd_from_line, footnote)
      num85 = parser.send(:extract_industry_number_before_bcd, footnote, bcd85[:position])
      assert_equal "85", num85
    end
  end
end
