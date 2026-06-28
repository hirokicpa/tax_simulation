# frozen_string_literal: true

module Simulations
  module BusinessSuccessionDiagnosisHelper
    RETURN_PARAM_KEYS = %i[
      president_age
      successor_status
      sales
      operating_profit
      net_assets
      debt
      real_estate_value
      other_assets
      has_spouse
      count_heir_children
      spouse_acquisition_rate
      cash_assets
      company_value
    ].freeze

    RETURN_CONTEXT = "business_succession_diagnosis"

    def diagnosis_return_active?(source = params)
      source[:return_context].to_s == RETURN_CONTEXT
    end

    def extract_diagnosis_return_params(source)
      result = RETURN_PARAM_KEYS.index_with do |key|
        value = source[:"diagnosis_#{key}"]
        value = source[key] if value.blank? && key == :company_value
        value.presence
      end.compact
      result.delete(:spouse_acquisition_rate) unless result[:has_spouse].to_s == "1"
      result
    end

    def diagnosis_return_query_params(diagnosis_params)
      query = { return_context: RETURN_CONTEXT }
      diagnosis_params.each do |key, value|
        query[:"diagnosis_#{key}"] = value if value.present?
      end
      query
    end

    def diagnosis_index_path_with(diagnosis_params, company_value_man: nil)
      merged = diagnosis_params.stringify_keys
      merged["company_value"] = company_value_man if company_value_man.present?
      simulations_business_succession_diagnosis_path(merged)
    end

    def stock_valuation_from_diagnosis_path(diagnosis_params)
      simulations_stock_valuation_path(diagnosis_return_query_params(diagnosis_params))
    end

    def yen_to_diagnosis_man_yen(yen)
      (yen.to_f / 10_000).round
    end

    def diagnosis_man_yen(amount)
      return "—" if amount.nil?

      "#{number_with_delimiter((amount.to_i / 10_000.0).round)}万円"
    end

    def diagnosis_yen(amount)
      "#{number_with_delimiter(amount.to_i)}円"
    end

    def risk_level_badge_class(level)
      case level
      when "低" then "badge-success"
      when "中" then "badge-warning"
      else "badge-danger"
      end
    end

    def risk_level_bar_class(level)
      case level
      when "低" then "bg-success"
      when "中" then "bg-warning"
      else "bg-danger"
      end
    end

    def diagnosis_section_html(text)
      return "" if text.blank?

      simple_format(h(text), {}, sanitize: false)
    end

    def spouse_rate_options(selected = nil, apply_default: true)
      rates = (0..10).map { |i| ["#{i * 10}%", i * 10] }
      chosen = selected.presence
      chosen ||= 50 if apply_default
      options_for_select(rates, chosen)
    end
  end
end
