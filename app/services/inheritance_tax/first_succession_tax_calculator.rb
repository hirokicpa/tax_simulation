# frozen_string_literal: true

module InheritanceTax
  # 相続税概算（配偶者＋子／配偶者のみ／子のみ）。金額単位はすべて万円。
  class FirstSuccessionTaxCalculator
    MAX_TAX_LIMIT = 16_000
    MARITAL_RATE_STEPS = (0..10).map { |i| i / 10.0 }.freeze

    Result = Struct.new(
      :tax_man,
      :gross_tax_man,
      :total_heritage_man,
      :basic_reduction_man,
      :taxable_price_man,
      :count_heir_children,
      :has_spouse,
      :marital_rate,
      :method_label,
      keyword_init: true
    )

    RateResult = Struct.new(:rate, :label, :tax_man, :gross_tax_man, :detail, keyword_init: true)

    def initialize(total_heritage_man:, count_heir_children:, has_spouse:, marital_rate: nil)
      @total_heritage = total_heritage_man.to_i
      @count_heir_children = count_heir_children.to_i
      @has_spouse = has_spouse
      @marital_rate = marital_rate.nil? ? default_marital_rate : marital_rate.to_f
    end

    def call
      return zero_result if @total_heritage <= 0

      if @has_spouse && @count_heir_children.positive?
        calculate_spouse_and_children
      elsif @has_spouse
        calculate_spouse_only
      elsif @count_heir_children.positive?
        calculate_children_only
      else
        zero_result
      end
    end

    def self.calculate_all_spouse_rates(total_heritage_man:, count_heir_children:, has_spouse:)
      return [] unless has_spouse

      MARITAL_RATE_STEPS.map do |rate|
        detail = new(
          total_heritage_man: total_heritage_man,
          count_heir_children: count_heir_children,
          has_spouse: true,
          marital_rate: rate
        ).call

        RateResult.new(
          rate: rate,
          label: "#{(rate * 100).round}%",
          tax_man: detail.tax_man,
          gross_tax_man: detail.gross_tax_man,
          detail: detail
        )
      end
    end

    def self.souzoku_tax(sum)
      if sum <= 1000
        (sum * 0.1).to_f
      elsif sum <= 3000
        ((sum * 0.15) - 50).to_f
      elsif sum <= 5000
        ((sum * 0.2) - 200).to_f
      elsif sum <= 10_000
        ((sum * 0.3) - 700).to_f
      elsif sum <= 20_000
        ((sum * 0.40) - 1700).to_f
      elsif sum <= 30_000
        ((sum * 0.45) - 2700).to_f
      elsif sum <= 60_000
        ((sum * 0.50) - 4200).to_f
      else
        ((sum * 0.55) - 7200).to_f
      end
    end

    private

    def default_marital_rate
      @has_spouse ? 0.5 : 0.0
    end

    def calculate_spouse_and_children
      basic = 3000 + (600 * (@count_heir_children + 1))
      taxable = [(@total_heritage - basic), 0].max
      return build_result(0, 0, basic, taxable, "配偶者＋子（課税遺産なし）") if taxable <= 0

      tax = if @total_heritage <= MAX_TAX_LIMIT || @marital_rate <= 0.5
              first_succession_a(taxable)
            else
              first_succession_b(taxable)
            end
      gross = gross_tax_spouse_and_children(taxable)

      build_result(tax, gross, basic, taxable, "配偶者＋子（配偶者#{percent_label(@marital_rate)}取得・税額軽減反映）")
    end

    def gross_tax_spouse_and_children(taxable_price)
      mate_share = (taxable_price / 2.0)
      child_share = (taxable_price / 2.0) / @count_heir_children
      mate_tax = self.class.souzoku_tax(mate_share)
      child_tax = self.class.souzoku_tax(child_share)
      (mate_tax.floor + (child_tax.floor * @count_heir_children))
    end

    def first_succession_a(taxable_price)
      gross = gross_tax_spouse_and_children(taxable_price)
      (gross * (1 - @marital_rate)).floor
    end

    def first_succession_b(taxable_price)
      mate_share = (taxable_price / 2.0)
      child_share = (taxable_price / 2.0) / @count_heir_children
      mate_tax = self.class.souzoku_tax(mate_share)
      child_tax = self.class.souzoku_tax(child_share)
      total = mate_tax + (child_tax * @count_heir_children)
      gross = total.floor

      reduction_ratio = if (@total_heritage * 0.5) > MAX_TAX_LIMIT
                          (@total_heritage * 0.5).to_f / @total_heritage
                        elsif @total_heritage * @marital_rate >= MAX_TAX_LIMIT
                          MAX_TAX_LIMIT.to_f / @total_heritage
                        else
                          (@total_heritage * @marital_rate).to_f / @total_heritage
                        end

      (total * (1 - @marital_rate) + total * @marital_rate - total * reduction_ratio).floor
    end

    def calculate_children_only
      basic = 3000 + (600 * @count_heir_children)
      taxable = [(@total_heritage - basic), 0].max
      return build_result(0, 0, basic, taxable, "子のみ（課税遺産なし）") if taxable <= 0

      child_share = taxable.to_f / @count_heir_children
      child_tax = self.class.souzoku_tax(child_share)
      tax = (child_tax.floor * @count_heir_children)
      build_result(tax, tax, basic, taxable, "子のみ")
    end

    def calculate_spouse_only
      basic = 3000 + 600
      taxable = [(@total_heritage - basic), 0].max
      return build_result(0, 0, basic, taxable, "配偶者のみ（課税遺産なし）") if taxable <= 0

      gross = self.class.souzoku_tax(taxable.to_f).floor
      tax = (gross * (1 - @marital_rate)).floor
      build_result(tax, gross, basic, taxable, "配偶者のみ（配偶者#{percent_label(@marital_rate)}取得・税額軽減反映）")
    end

    def build_result(tax, gross, basic, taxable, method_label)
      Result.new(
        tax_man: [tax, 0].max,
        gross_tax_man: [gross, 0].max,
        total_heritage_man: @total_heritage,
        basic_reduction_man: basic,
        taxable_price_man: taxable,
        count_heir_children: @count_heir_children,
        has_spouse: @has_spouse,
        marital_rate: @marital_rate,
        method_label: method_label
      )
    end

    def zero_result
      Result.new(
        tax_man: 0,
        gross_tax_man: 0,
        total_heritage_man: @total_heritage,
        basic_reduction_man: 0,
        taxable_price_man: 0,
        count_heir_children: @count_heir_children,
        has_spouse: @has_spouse,
        marital_rate: @marital_rate,
        method_label: "算出対象外"
      )
    end

    def percent_label(rate)
      "#{(rate * 100).round}%"
    end
  end
end
