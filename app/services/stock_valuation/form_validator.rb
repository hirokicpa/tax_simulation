# frozen_string_literal: true

module StockValuation
  class FormValidator
    COMPANY_SIZE_AMOUNT_FIELDS = {
      total_assets: "総資産価額",
      annual_sales: "直前期末以前1年間における取引金額"
    }.freeze

    MONEY_FIELDS = {
      capital_amount: "資本金等",
      annual_dividend: "年配当金額",
      annual_profit: "利益金額",
      net_assets: "純資産額"
    }.freeze

    OPTIONAL_SEN_FIELDS = {
      inheritance_net_assets: "純資産価額（相続税評価額）"
    }.freeze

    def initialize(params)
      @params = params
      @errors = []
    end

    attr_reader :errors

    def valid?
      validate_presence
      validate_money_fields
      validate_employees
      validate_shares
      validate_industry_type
      validate_similar_industry
      validate_optional_sen_fields
      @errors.empty?
    end

    def parsed
      {
        total_assets: parse_sen_yen(:total_assets),
        annual_sales: parse_sen_yen(:annual_sales),
        employees: @params[:employees].to_s.delete(",").to_i,
        industry_type: @params[:industry_type].to_s,
        similar_industry_id: @params[:similar_industry_id],
        capital_amount: parse_sen_yen(:capital_amount),
        issued_shares: @params[:issued_shares].to_s.delete(",").to_i,
        annual_dividend: parse_sen_yen(:annual_dividend),
        annual_profit: parse_sen_yen(:annual_profit),
        net_assets: parse_sen_yen(:net_assets),
        inheritance_net_assets: parse_optional_sen_yen(:inheritance_net_assets)
      }
    end

    private

    def validate_presence
      required = COMPANY_SIZE_AMOUNT_FIELDS.keys + MONEY_FIELDS.keys + [:employees, :issued_shares, :industry_type, :similar_industry_id]
      required.each do |key|
        @errors << "#{label_for(key)}を入力してください。" if @params[key].blank?
      end
    end

    def validate_money_fields
      COMPANY_SIZE_AMOUNT_FIELDS.each_key do |key|
        next if @params[key].blank?

        @errors << "#{COMPANY_SIZE_AMOUNT_FIELDS[key]}は0以上の数値で入力してください。" if parse_sen_yen(key).negative?
      end

      MONEY_FIELDS.each_key do |key|
        next if @params[key].blank?

        @errors << "#{MONEY_FIELDS[key]}は0以上の数値で入力してください。" if parse_sen_yen(key).negative?
      end
    end

    def validate_employees
      return if @params[:employees].blank?

      @errors << "従業員数は0以上の整数で入力してください。" if @params[:employees].to_s.delete(",").to_i.negative?
    end

    def validate_shares
      return if @params[:issued_shares].blank?

      shares = @params[:issued_shares].to_s.delete(",").to_i
      @errors << "発行済株式総数は1以上で入力してください。" if shares <= 0
    end

    def validate_industry_type
      return if @params[:industry_type].blank?

      unless CompanySizeJudger::INDUSTRY_TYPES.key?(@params[:industry_type].to_s)
        @errors << "業種区分を正しく選択してください。"
      end
    end

    def validate_similar_industry
      return if @params[:similar_industry_id].blank?

      unless SimilarIndustry.exists?(@params[:similar_industry_id])
        @errors << "選択した業種が見つかりません。類似業種データを取込してください。"
      end
    end

    def validate_optional_sen_fields
      OPTIONAL_SEN_FIELDS.each_key do |key|
        next if @params[key].blank?

        @errors << "#{OPTIONAL_SEN_FIELDS[key]}は0以上の数値で入力してください。" if parse_optional_sen_yen(key).negative?
      end
    end

    def parse_optional_sen_yen(key)
      return nil if @params[key].blank?

      parse_sen_yen(key)
    end

    def parse_yen(key)
      @params[key].to_s.delete(",").to_i
    end

    def parse_sen_yen(key)
      parse_yen(key) * 1000
    end

    def label_for(key)
      {
        employees: "従業員数",
        industry_type: "業種区分",
        similar_industry_id: "業種",
        issued_shares: "発行済株式総数"
      }.merge(COMPANY_SIZE_AMOUNT_FIELDS, MONEY_FIELDS, OPTIONAL_SEN_FIELDS).fetch(key)
    end
  end
end
