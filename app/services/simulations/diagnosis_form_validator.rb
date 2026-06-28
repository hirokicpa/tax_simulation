# frozen_string_literal: true

module Simulations
  class DiagnosisFormValidator
    REQUIRED_FIELDS = {
      president_age: "代表者年齢",
      successor_status: "後継者の有無",
      sales: "売上",
      operating_profit: "営業利益",
      net_assets: "純資産",
      debt: "借入金",
      real_estate_value: "不動産（相続財産）",
      other_assets: "それ以外の財産",
      has_spouse: "配偶者の有無",
      count_heir_children: "子供の人数",
      cash_assets: "納税資金（現預金）"
    }.freeze

    OPTIONAL_MAN_FIELDS = {
      company_value: "自社株評価額"
    }.freeze

    def initialize(params)
      @params = params
      @errors = []
    end

    attr_reader :errors

    def valid?
      validate_presence
      validate_numbers
      validate_successor
      validate_heirs
      validate_spouse_rate
      @errors.empty?
    end

    def parsed
      base = REQUIRED_FIELDS.keys.index_with { |key| @params[key] }
      OPTIONAL_MAN_FIELDS.each_key { |key| base[key] = @params[key] }
      base[:successor_status] = @params[:successor_status].to_s
      base[:has_spouse] = @params[:has_spouse].to_s
      base[:count_heir_children] = @params[:count_heir_children].to_s
      base[:spouse_acquisition_rate] = @params[:spouse_acquisition_rate].to_s if @params[:has_spouse].to_s == "1"
      base
    end

    private

    def validate_presence
      REQUIRED_FIELDS.each do |key, label|
        @errors << "#{label}を入力してください。" if @params[key].blank?
      end
    end

    def validate_numbers
      REQUIRED_FIELDS.each_key do |key|
        next if @params[key].blank?

        if key == :president_age
          age = @params[key].to_i
          @errors << "代表者年齢は18〜100の整数で入力してください。" unless age.between?(18, 100)
        elsif key == :count_heir_children
          count = @params[key].to_i
          @errors << "子供の人数は0〜5の整数で入力してください。" unless count.between?(0, 5)
        elsif parse_man_yen(key).negative?
          @errors << "#{REQUIRED_FIELDS[key]}は0以上の数値で入力してください。"
        end
      end

      OPTIONAL_MAN_FIELDS.each_key do |key|
        next if @params[key].blank?

        @errors << "#{OPTIONAL_MAN_FIELDS[key]}は0以上の数値で入力してください。" if parse_man_yen(key).negative?
      end
    end

    def validate_successor
      return if @params[:successor_status].blank?

      unless BusinessSuccessionDiagnosisService::SUCCESSOR_LABELS.key?(@params[:successor_status].to_s)
        @errors << "後継者の有無を正しく選択してください。"
      end
    end

    def validate_heirs
      return if @params[:has_spouse].blank? || @params[:count_heir_children].blank?

      has_spouse = @params[:has_spouse].to_s == "1"
      count = @params[:count_heir_children].to_i

      if !has_spouse && count.zero?
        @errors << "配偶者がいない場合は、子供の人数を1人以上入力してください。"
      end

      if !has_spouse && !count.zero? && count.negative?
        @errors << "子供の人数を正しく入力してください。"
      end
    end

    def validate_spouse_rate
      return unless @params[:has_spouse].to_s == "1"

      if @params[:spouse_acquisition_rate].blank?
        @errors << "配偶者の遺産取得割合を選択してください。"
        return
      end

      rate = @params[:spouse_acquisition_rate].to_i
      unless rate.between?(0, 100) && (rate % 10).zero?
        @errors << "配偶者の遺産取得割合は0〜100%（10%刻み）で選択してください。"
      end
    end

    def parse_man_yen(key)
      @params[key].to_s.delete(",").to_i
    end
  end
end
