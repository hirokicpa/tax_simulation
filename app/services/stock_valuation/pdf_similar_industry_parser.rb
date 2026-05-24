# frozen_string_literal: true

require "pdf/reader"
require "bigdecimal"

module StockValuation
  # 国税庁「業種目別株価等一覧表」PDF（list_01.pdf / list_all.pdf 等）
  class PdfSimilarIndustryParser
    SKIP_PATTERN = /別紙|類似業種|単位|業種目|大分類|中分類|小分類|配当|利益|簿価|留意|注\)|ページ|－|上段|下段|令和|年分|月分|公表|^\s*-\s*\d+\s*-/x
    INVALID_NAME_PATTERN = /令和|年分|月分|公表|年月|月分/
    MAX_INDUSTRY_NUMBER = SimilarIndustry::MAX_INDUSTRY_NUMBER
    MAX_STOCK_PRICE = 50_000
    def initialize(pdf_io)
      @pdf_io = pdf_io
    end

    def parse
      page1_rows = {}
      page2_a = {}

      PDF::Reader.new(@pdf_io).pages.each do |page|
        text = normalize(page.text)
        parse_summary_page(text).each { |key, row| page1_rows[key] = row }
        parse_stock_price_page(text).each { |key, avg| page2_a[key] = avg }
      end

      merge_rows(page1_rows, page2_a).select { |row| valid_row?(row) }
    end

    private

    def normalize(text)
      text.to_s.tr("\r", "\n").unicode_normalize(:nfkc)
    end

    def parse_summary_page(text)
      rows = {}
      return rows unless text

      text.each_line do |line|
        line = line.strip
        next if line.blank? || line.match?(SKIP_PATTERN)

        bcd = extract_bcd_from_line(line)
        next unless bcd

        number = extract_industry_number_before_bcd(line, bcd[:position])
        next unless number

        b, c, d = bcd.values_at(:b, :c, :d)
        prior_year_a = extract_prior_year_stock_price(line, bcd)

        name = extract_name(line, number)
        next if name.blank? || invalid_industry_name?(name)

        candidate = {
          industry_number: number,
          industry_name: name,
          dividend_b: b,
          profit_c: c,
          net_asset_d: d,
          stock_price_a_average: prior_year_a
        }
        rows[number] = rows[number] ? prefer_industry_row(rows[number], candidate) : candidate
      end
      rows
    end

    def extract_bcd_from_line(line)
      normalized = line.tr("０-９", "0-9")
      start = normalized.index(/\d{1,2}\.\d/)
      return nil unless start

      tail = normalized[start..]

      [/\A(\d{2}\.\d)(\d{2})(\d{3})(?:\s|$)/, /\A(\d\.\d)(\d{2})(\d{3})(?:\s|$)/].each do |pattern|
        glued = tail.match(pattern)
        next unless glued

        b, c, d = BigDecimal(glued[1]), BigDecimal(glued[2]), BigDecimal(glued[3])
        return bcd_hash(b, c, d, start) if valid_bcd_values?(b, c, d)
      end

      split_token = tail.match(/\A(\d{1,2})\.(\d{3})\s+(\d{3})(\d*)/)
      if split_token
        b = BigDecimal("#{split_token[1]}.#{split_token[2][0]}")
        c = BigDecimal(split_token[2][1, 2])
        d = BigDecimal(split_token[3])
        return bcd_hash(b, c, d, start) if valid_bcd_values?(b, c, d)
      end

      single_digit_split = tail.match(/\A(\d)\.(\d{3})\s+(\d{3})(\d*)/)
      if single_digit_split
        b = BigDecimal("#{single_digit_split[1]}.#{single_digit_split[2][0]}")
        c = BigDecimal(single_digit_split[2][1, 2])
        d = BigDecimal(single_digit_split[3])
        return bcd_hash(b, c, d, start) if valid_bcd_values?(b, c, d)
      end

      spaced = tail.match(/\A(\d+\.\d+)\s+(\d+)\s+(\d+)/)
      if spaced
        b, c, d = BigDecimal(spaced[1]), BigDecimal(spaced[2]), BigDecimal(spaced[3])
        return bcd_hash(b, c, d, start) if valid_bcd_values?(b, c, d)
      end

      nil
    end

    def bcd_hash(b, c, d, position)
      { b: b, c: c, d: d, position: position }
    end

    def valid_bcd_values?(b, c, d)
      b.positive? && b < 100 && c >= 0 && c < 500 && d.positive? && d < 3000
    end

    def extract_industry_number_before_bcd(line, bcd_position)
      before = strip_footnote_suffix(line.tr("０-９", "0-9")[0...bcd_position].to_s)

      # 業種番号の直後に業種説明が続くパターン（79 百貨店… / 85 小売業(…）
      numbers = before.scan(/(\d{1,3})\s+(?=[^0-9.\s])/).filter_map do |match|
        num = match.first.to_i
        num if num.between?(1, MAX_INDUSTRY_NUMBER)
      end
      return format_number(numbers.last) if numbers.any?

      if before.match(/業(\d{1,3})\s/)
        num = ::Regexp.last_match(1).to_i
        return format_number(num) if num.between?(1, MAX_INDUSTRY_NUMBER)
      end

      if before.match(/(\d{1,3})業/)
        num = ::Regexp.last_match(1).to_i
        return format_number(num) if num.between?(1, MAX_INDUSTRY_NUMBER)
      end

      before.scan(/(?:^|[^\d])(\d{1,3})(?=\s)/).each do |match|
        num = match.first.to_i
        return format_number(num) if num.between?(1, MAX_INDUSTRY_NUMBER)
      end

      nil
    end

    def strip_footnote_suffix(before)
      before.sub(/のうち[、,]\s*\d+\s*\z/, "")
            .sub(/から\d+に?該当[^\d]*\z/, "")
    end

    def prefer_industry_row(incumbent, challenger)
      industry_row_quality(challenger) > industry_row_quality(incumbent) ? challenger : incumbent
    end

    def industry_row_quality(row)
      name = row[:industry_name].to_s
      score = name.gsub(/[　\s]/, "").length
      score -= 100 if name.match?(/のうち|を除く|に該当/)
      score -= 50 if name.match?(/[業]..*業.*\(/)
      score
    end

    def parse_stock_price_page(text)
      result = {}
      return result unless text

      pending_number = nil

      text.each_line do |line|
        line = line.strip
        next if line.blank? || line.match?(SKIP_PATTERN)

        number = extract_industry_number(line)
        upper_prices = number ? extract_values(line, number) : []

        if number && upper_prices.size >= 10
          pending_number = number
          next
        end

        next unless pending_number

        lower_prices = extract_values(line, pending_number)
        next if lower_prices.size < 10

        price = prior_year_average_stock_price_from_lower_row(lower_prices)
        result[pending_number] = price if price.positive? && price <= MAX_STOCK_PRICE
        pending_number = nil
      end

      result
    end

    # 類似業種株価A：B・C・D直後の第1数値＝令和6年平均（前年平均株価）
    def extract_prior_year_stock_price(line, bcd)
      a_prices = extract_stock_prices_after_bcd(line, bcd)
      price = a_prices.first
      return nil if price.nil?

      value = price.to_f
      value.positive? && value <= MAX_STOCK_PRICE ? value.round(2) : nil
    end

    def extract_stock_prices_after_bcd(line, bcd)
      tail = line.tr("０-９", "0-9")[bcd[:position]..].to_s
      comma_style = tail.scan(/1,\d{3}/).map { |token| BigDecimal(token.delete(",")) }
      return comma_style if comma_style.any?

      nums = tail.scan(/\d+(?:\.\d+)?/).map { |n| BigDecimal(n) }
      strip_leading_bcd_numbers(nums, bcd)
    end

    # PDFでは配当・利益が「10.152」のように結合されるため、先頭3数値をB/C/Dと
    # 誤って株価から除外しない（例: No.30 → 439 が D に取り込まれ 437 になる不具合）
    def strip_leading_bcd_numbers(nums, bcd)
      b, c, d = bcd.values_at(:b, :c, :d)
      rest = nums.dup
      return rest if rest.empty?

      if glued_bc_token?(rest[0], b, c)
        rest.shift
      elsif close_enough?(rest[0], b)
        rest.shift
        rest.shift if rest[0] && close_enough?(rest[0], c)
      end

      rest.shift if rest[0] && close_enough?(rest[0], d)

      rest
    end

    def glued_bc_token?(token, b, c)
      b_str = format("%.1f", b.to_f)
      expected = "#{b_str}#{c.to_i}"
      close_enough?(token, BigDecimal(expected)) || token.to_s("F") == expected
    rescue ArgumentError
      false
    end

    def close_enough?(value, target)
      return false if value.nil? || target.nil?

      (value.to_f - target.to_f).abs < 0.01
    end

    # 2ページ目下段（2年間平均株価・直近月）— 1ページ目に前年平均が無い場合の補完用
    def prior_year_average_stock_price_from_lower_row(prices)
      prices.last.to_f.round(2)
    end

    def merge_rows(page1_rows, page2_a)
      page1_rows.keys.sort_by(&:to_i).filter_map do |number|
        base = page1_rows[number]
        next unless base

        a = base[:stock_price_a_average].to_f
        a = page2_a[number].to_f if a.zero? && page2_a[number].to_f.positive?
        next if a.zero?

        base.merge(stock_price_a_average: a)
      end
    end

    def valid_row?(row)
      num = row[:industry_number].to_i
      a = row[:stock_price_a_average].to_f
      return false if num < 1 || num > MAX_INDUSTRY_NUMBER
      return false if a <= 0 || a > MAX_STOCK_PRICE
      return false if row[:profit_c].to_f.zero? || row[:net_asset_d].to_f.zero?
      return false if invalid_industry_name?(row[:industry_name])
      return false if row[:industry_name].match?(/\A業種\d+\z/) && row[:dividend_b].to_f.zero?

      true
    end

    def invalid_industry_name?(name)
      name.to_s.match?(INVALID_NAME_PATTERN)
    end

    def extract_industry_number(line)
      bcd = extract_bcd_from_line(line)
      if bcd
        num = extract_industry_number_before_bcd(line, bcd[:position])
        return num if num
      end

      extract_industry_number_for_stock_line(line.tr("０-９", "0-9"))
    end

    def extract_industry_number_for_stock_line(normalized)
      if normalized.match(/(?:^|[^\d])(\d{1,3})\s+(?:\d{2,4}\s+){8,}/)
        num = ::Regexp.last_match(1).to_i
        return format_number(num) if num.between?(1, MAX_INDUSTRY_NUMBER)
      end

      nil
    end

    def format_number(value)
      value.to_s
    end

    def extract_values(line, industry_number)
      nums = line.scan(/\d+(?:\.\d+)?/).map { |n| BigDecimal(n) }
      nums.reject do |n|
        n.frac.zero? && n.to_i == industry_number.to_i && n.to_i < 150
      end
    end

    def extract_name(line, number)
      normalized = line.tr("０-９", "0-9")
      idx = normalized.index(number)
      return nil unless idx

      prefix = normalized[0...idx].gsub(/[0-9\.]+/, " ").gsub(/[　\s]+/, " ").strip
      rest = normalized[(idx + number.length)..]
      suffix = nil
      if rest&.match(/\A\s*(.+?)\s+\d+\.\d+\s+\d+\s+\d/)
        suffix = ::Regexp.last_match(1).gsub(/[　\s]+/, " ").strip
      end

      name = if prefix.present?
               prefix
             else
               suffix
             end

      return nil if name.blank? || invalid_industry_name?(name)

      name
    end

    def extract_bcd_a(numbers)
      return [0, 0, 0, nil] if numbers.size < 3

      b, c, d = numbers[0], numbers[1], numbers[2]
      avg_a = average_optional(numbers[3..])
      [b, c, d, avg_a]
    end

    def average_optional(values)
      return nil if values.blank?

      (values.sum / values.size).round(2)
    end
  end
end
