# frozen_string_literal: true

# 事業承継リスク診断：税額・株価・スコアはルールベースで算出（AIは使わない）
class BusinessSuccessionDiagnosisService
  SUCCESSOR_LABELS = {
    "yes" => "後継者あり",
    "no" => "後継者なし",
    "undecided" => "未定"
  }.freeze

  Result = Struct.new(
    :president_age,
    :successor_status,
    :successor_label,
    :sales,
    :operating_profit,
    :net_assets,
    :company_value,
    :company_value_estimated,
    :debt,
    :real_estate_value,
    :other_assets,
    :has_spouse,
    :count_heir_children,
    :spouse_acquisition_rate,
    :cash_assets,
    :total_estate,
    :estimated_inheritance_tax,
    :inheritance_tax_detail,
    :inheritance_tax_by_spouse_rate,
    :taxable_estate,
    :tax_payment_shortage,
    :succession_risk_score,
    :succession_risk_level,
    :stock_risk_score,
    :stock_risk_level,
    :tax_funding_risk_score,
    :tax_funding_risk_level,
    :ma_necessity_score,
    :ma_necessity_level,
    :overall_risk_score,
    :overall_risk_level,
    :risk_breakdown,
    :immediate_actions,
    keyword_init: true
  )

  def initialize(params)
    @params = params
  end

  def call
    company_value, estimated = resolve_company_value
    total_estate = total_estate_yen(company_value)
    tax_result = calculate_inheritance_tax(total_estate)
    tax_detail = tax_result[:detail]
    inheritance_tax = tax_detail.tax_man * 10_000

    Result.new(
      president_age: president_age,
      successor_status: successor_status,
      successor_label: SUCCESSOR_LABELS.fetch(successor_status, successor_status),
      sales: sales,
      operating_profit: operating_profit,
      net_assets: net_assets,
      company_value: company_value,
      company_value_estimated: estimated,
      debt: debt,
      real_estate_value: real_estate_value,
      other_assets: other_assets,
      has_spouse: has_spouse,
      count_heir_children: count_heir_children,
      spouse_acquisition_rate: spouse_acquisition_rate,
      cash_assets: cash_assets,
      total_estate: total_estate,
      estimated_inheritance_tax: inheritance_tax,
      inheritance_tax_detail: tax_detail,
      inheritance_tax_by_spouse_rate: tax_result[:by_spouse_rate],
      taxable_estate: tax_detail.taxable_price_man * 10_000,
      tax_payment_shortage: inheritance_tax - cash_assets,
      succession_risk_score: succession_risk_score,
      succession_risk_level: level_for(succession_risk_score),
      stock_risk_score: stock_risk_score(company_value),
      stock_risk_level: level_for(stock_risk_score(company_value)),
      tax_funding_risk_score: tax_funding_risk_score(inheritance_tax),
      tax_funding_risk_level: level_for(tax_funding_risk_score(inheritance_tax)),
      ma_necessity_score: ma_necessity_score,
      ma_necessity_level: level_for(ma_necessity_score, high_label: "要検討"),
      overall_risk_score: overall_risk_score(company_value, inheritance_tax),
      overall_risk_level: level_for(overall_risk_score(company_value, inheritance_tax)),
      risk_breakdown: risk_breakdown(company_value, inheritance_tax),
      immediate_actions: rule_based_actions(company_value, inheritance_tax)
    )
  end

  private

  def man_yen(key)
    @params[key].to_s.delete(",").to_i * 10_000
  end

  def man_yen_raw(key)
    @params[key].to_s.delete(",").to_i
  end

  def president_age
    @params[:president_age].to_i
  end

  def successor_status
    status = @params[:successor_status].to_s
    SUCCESSOR_LABELS.key?(status) ? status : "undecided"
  end

  def sales
    man_yen(:sales)
  end

  def operating_profit
    man_yen(:operating_profit)
  end

  def net_assets
    man_yen(:net_assets)
  end

  def debt
    man_yen(:debt)
  end

  def real_estate_value
    man_yen(:real_estate_value)
  end

  def other_assets
    man_yen(:other_assets)
  end

  def cash_assets
    man_yen(:cash_assets)
  end

  def count_heir_children
    @params[:count_heir_children].to_i
  end

  def spouse_acquisition_rate
    return nil unless has_spouse

    raw = @params[:spouse_acquisition_rate].to_s
    return 50 if raw.blank?

    raw.to_i.clamp(0, 100)
  end

  def has_spouse
    @params[:has_spouse].to_s == "1"
  end

  def input_company_value
    value = @params[:company_value].to_s.delete(",")
    return nil if value.blank?

    value.to_i * 10_000
  end

  def estimated_company_value
    net_assets + (operating_profit * 3)
  end

  def resolve_company_value
    input = input_company_value
    return [input, false] if input&.positive?

    [estimated_company_value, true]
  end

  def total_estate_yen(company_value)
    company_value + real_estate_value + other_assets + cash_assets
  end

  def total_estate_man(company_value)
    (total_estate_yen(company_value) / 10_000.0).round
  end

  def calculate_inheritance_tax(_total_estate_yen)
    company_value, = resolve_company_value
    heritage_man = total_estate_man(company_value)

    if has_spouse
      by_rate = InheritanceTax::FirstSuccessionTaxCalculator.calculate_all_spouse_rates(
        total_heritage_man: heritage_man,
        count_heir_children: count_heir_children,
        has_spouse: true
      )
      selected_rate = spouse_acquisition_rate / 100.0
      detail = by_rate.find { |row| (row.rate - selected_rate).abs < 0.001 }&.detail ||
               InheritanceTax::FirstSuccessionTaxCalculator.new(
                 total_heritage_man: heritage_man,
                 count_heir_children: count_heir_children,
                 has_spouse: true,
                 marital_rate: selected_rate
               ).call
      { detail: detail, by_spouse_rate: by_rate }
    else
      detail = InheritanceTax::FirstSuccessionTaxCalculator.new(
        total_heritage_man: heritage_man,
        count_heir_children: count_heir_children,
        has_spouse: false
      ).call
      { detail: detail, by_spouse_rate: nil }
    end
  end

  def tax_payment_shortage(inheritance_tax)
    inheritance_tax - cash_assets
  end

  def succession_risk_score
    score = 0
    score += 35 if successor_status == "no"
    score += 20 if successor_status == "undecided"
    score += 25 if president_age >= 70
    score += 15 if president_age >= 60 && president_age < 70
    score += 20 if operating_profit.positive? && successor_status != "yes"
    [score, 100].min
  end

  def stock_risk_score(company_value)
    score = 0
    score += 30 if company_value >= 300_000_000
    score += 20 if company_value >= 100_000_000 && company_value < 300_000_000
    score += 15 if operating_profit.positive? && company_value > net_assets * 2
    score += 15 if real_estate_value < company_value * 0.3 && company_value >= 50_000_000
    [score, 100].min
  end

  def tax_funding_risk_score(inheritance_tax)
    shortage = tax_payment_shortage(inheritance_tax)
    return 0 if inheritance_tax <= 0

    ratio = shortage.to_f / inheritance_tax
    score = 0
    score += 40 if shortage.positive?
    score += 25 if ratio >= 0.5
    score += 20 if ratio >= 1.0
    score += 15 if cash_assets < debt
    [score, 100].min
  end

  def ma_necessity_score
    score = 0
    score += 40 if successor_status == "no"
    score += 25 if successor_status == "undecided" && president_age >= 65
    score += 20 if operating_profit.positive? && sales >= 500_000_000
    score += 15 if president_age >= 70 && successor_status != "yes"
    [score, 100].min
  end

  def overall_risk_score(company_value, inheritance_tax)
    scores = [
      succession_risk_score,
      stock_risk_score(company_value),
      tax_funding_risk_score(inheritance_tax),
      ma_necessity_score
    ]
    (scores.sum.to_f / scores.size).round
  end

  def risk_breakdown(company_value, inheritance_tax)
    {
      "事業承継危険度" => succession_risk_score,
      "自社株リスク" => stock_risk_score(company_value),
      "納税資金不足リスク" => tax_funding_risk_score(inheritance_tax),
      "M&A検討必要度" => ma_necessity_score
    }
  end

  def level_for(score, high_label: "高")
    case score
    when 0..39 then "低"
    when 40..69 then "中"
    else high_label
    end
  end

  def rule_based_actions(company_value, inheritance_tax)
    actions = []
    actions << "後継者候補の選定と事業承継計画の策定を検討してください。" if successor_status != "yes"
    actions << "自社株評価の把握と、評価額引下げの可能性について専門家に確認してください。" if stock_risk_score(company_value) >= 40
    actions << "相続税納税資金の確保方法（生命保険・借入・資産売却等）を検討してください。" if tax_payment_shortage(inheritance_tax).positive?
    actions << "納税資金の不足が見込まれるため、早めの資金計画が必要です。" if tax_funding_risk_score(inheritance_tax) >= 40
    actions << "M&A・外部承継の選択肢も含め、承継ルートの比較検討余地があります。" if ma_necessity_score >= 40
    actions << "代表者の高齢化に伴い、承継準備の時間的余裕が限られています。早めの専門家相談をお勧めします。" if president_age >= 70
    actions << "現状、大きな緊急リスクは見られませんが、定期的な見直しをお勧めします。" if actions.empty?
    actions.first(5)
  end
end
