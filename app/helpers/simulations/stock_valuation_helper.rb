# frozen_string_literal: true

module Simulations::StockValuationHelper
  def stock_yen(value, precision: 0)
    number = value.to_f
    formatted = number_with_delimiter(precision.positive? ? number.round(precision) : number.floor)
    "#{formatted}円"
  end

  def stock_man_yen(value, precision: 2)
    man = (value.to_f / 10_000).round(precision)
    formatted = precision.positive? ? man : man.to_i
    "#{number_with_delimiter(formatted)}万円"
  end

  def stock_sen_yen(value)
    sen = (value.to_f / 1000).floor
    "#{number_with_delimiter(sen)}千円"
  end

  def stock_ratio(value)
    format("%.4f", value.to_f)
  end

  def company_size_judger_config_json
    StockValuation::CompanySizeJudger.js_config.to_json
  end
end
