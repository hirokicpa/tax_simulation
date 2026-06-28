# frozen_string_literal: true

class Simulations::StockValuationController < ApplicationController
  include Simulations::BusinessSuccessionDiagnosisHelper

  helper Simulations::StockValuationHelper
  helper Simulations::BusinessSuccessionDiagnosisHelper

  def index
    @industry_types = ::StockValuation::CompanySizeJudger::INDUSTRY_TYPES
    setup_diagnosis_return

    unless similar_industries_table_exists?
      @data_setup_required = true
      @similar_industries = []
      @data_imported = false
      return
    end

    ensure_similar_industries_loaded
    @similar_industries = load_similar_industries_for_select
    @data_imported = @similar_industries.any?
  end

  def result
    validator = ::StockValuation::FormValidator.new(stock_valuation_params)
    unless validator.valid?
      flash.now[:alert] = validator.errors
      return render_index_with_errors
    end

    unless ensure_similar_industries_loaded
      flash.now[:alert] = [
        "類似業種データを取得できませんでした。ネットワーク接続を確認し、",
        "`rails similar_industries:import` または `rails similar_industries:import_r07_pdfs` を実行してください。"
      ]
      return render_index_with_errors
    end

    input = validator.parsed
    @similar_industry = SimilarIndustry.find(input[:similar_industry_id])

    @company_size = ::StockValuation::CompanySizeJudger.new(
      total_assets: input[:total_assets],
      annual_sales: input[:annual_sales],
      employees: input[:employees],
      industry_type: input[:industry_type]
    ).call

    @valuation = ::StockValuation::SimilarIndustryCalculator.new(
      capital_amount: input[:capital_amount],
      issued_shares: input[:issued_shares],
      annual_dividend: input[:annual_dividend],
      annual_profit: input[:annual_profit],
      net_assets: input[:net_assets],
      industry: @similar_industry,
      company_size: @company_size
    ).call

    @input = input
    @warnings = @valuation.warnings.dup
    if @company_size.size_code == :medium && input[:inheritance_net_assets].nil?
      @warnings << "中会社の評価には「3. 純資産価額（相続税評価額）」の入力を推奨します（第179条の併用計算）。"
    end

    if input[:inheritance_net_assets]
      @blended_valuation = ::StockValuation::BlendedStockValuationCalculator.new(
        similar_industry_per_share: @valuation.per_share_valuation,
        inheritance_net_assets: input[:inheritance_net_assets],
        company_size: @company_size,
        issued_shares: input[:issued_shares]
      ).call
    end

    setup_diagnosis_return
  end

  private

  def stock_valuation_params
    keys = [
      :total_assets,
      :annual_sales,
      :employees,
      :industry_type,
      :similar_industry_id,
      :capital_amount,
      :issued_shares,
      :annual_dividend,
      :annual_profit,
      :net_assets,
      :inheritance_net_assets,
      :return_context
    ]
    Simulations::BusinessSuccessionDiagnosisHelper::RETURN_PARAM_KEYS.each do |key|
      keys << :"diagnosis_#{key}"
    end
    params.permit(*keys)
  end

  def setup_diagnosis_return
    return unless diagnosis_return_active?(params)

    @diagnosis_return_active = true
    @diagnosis_return_params = extract_diagnosis_return_params(params)
  end

  def render_index_with_errors
    @similar_industries = load_similar_industries_for_select
    @industry_types = ::StockValuation::CompanySizeJudger::INDUSTRY_TYPES
    @data_imported = @similar_industries.any?
    setup_diagnosis_return
    render :index, status: :unprocessable_entity
  end

  def load_similar_industries_for_select
    SimilarIndustry.ordered_for_select
  end

  def similar_industries_table_exists?
    SimilarIndustry.table_exists?
  rescue ActiveRecord::StatementInvalid => e
    raise e unless e.message.include?("similar_industries")

    false
  end

  def ensure_similar_industries_loaded
    return false unless similar_industries_table_exists?

    loaded = ::StockValuation::SimilarIndustryImporter.ensure_data!
    SimilarIndustry.dedupe_for_year! if loaded && SimilarIndustry.needs_dedupe?
    loaded
  end
end
