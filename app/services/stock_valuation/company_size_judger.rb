# frozen_string_literal: true

module StockValuation
  # 国税庁通達第178条（取引相場のない株式の評価上の区分）に基づく会社規模判定
  # 金額閾値はすべて円（入力は千円→円に換算してから判定）
  class CompanySizeJudger
    EMPLOYEE_LARGE_THRESHOLD = 70
    EMPLOYEE_LARGE_ASSET_SALES_MIN = 36 # 35人以下の会社は資産・取引による大会社判定から除く

    INDUSTRY_TYPES = {
      "wholesale" => "卸売業",
      "retail_service" => "小売・サービス業",
      "other" => "卸売業・小売・サービス業以外"
    }.freeze

    # 第179条 Lの割合：イ（総資産・従業員数）※上位区分優先
    L_ASSET_TIERS = {
      "wholesale" => [
        { assets_min: 400_000_000, employees_min: 36, ratio: 0.90 },
        { assets_min: 200_000_000, employees_min: 21, ratio: 0.75 },
        { assets_min: 70_000_000, employees_min: 6, ratio: 0.60 }
      ],
      "retail_service" => [
        { assets_min: 500_000_000, employees_min: 36, ratio: 0.90 },
        { assets_min: 250_000_000, employees_min: 21, ratio: 0.75 },
        { assets_min: 40_000_000, employees_min: 6, ratio: 0.60 }
      ],
      "other" => [
        { assets_min: 500_000_000, employees_min: 36, ratio: 0.90 },
        { assets_min: 250_000_000, employees_min: 21, ratio: 0.75 },
        { assets_min: 50_000_000, employees_min: 6, ratio: 0.60 }
      ]
    }.freeze

    # 第179条 Lの割合：ロ（取引金額のレンジ）
    L_SALES_TIERS = {
      "wholesale" => [
        { sales_min: 700_000_000, sales_max: 3_000_000_000, ratio: 0.90 },
        { sales_min: 350_000_000, sales_max: 700_000_000, ratio: 0.75 },
        { sales_min: 200_000_000, sales_max: 350_000_000, ratio: 0.60 }
      ],
      "retail_service" => [
        { sales_min: 500_000_000, sales_max: 2_000_000_000, ratio: 0.90 },
        { sales_min: 250_000_000, sales_max: 500_000_000, ratio: 0.75 },
        { sales_min: 60_000_000, sales_max: 250_000_000, ratio: 0.60 }
      ],
      "other" => [
        { sales_min: 400_000_000, sales_max: 1_500_000_000, ratio: 0.90 },
        { sales_min: 200_000_000, sales_max: 400_000_000, ratio: 0.75 },
        { sales_min: 80_000_000, sales_max: 200_000_000, ratio: 0.60 }
      ]
    }.freeze

    # 第178条の規模区分表（円）
    SIZE_CRITERIA = {
      "wholesale" => {
        large: { assets_min: 20_000_000_000, sales_min: 30_000_000_000 },
        small: { assets_max: 70_000_000, sales_max: 200_000_000, employees_max: 5 }
      },
      "retail_service" => {
        large: { assets_min: 15_000_000_000, sales_min: 20_000_000_000 },
        small: { assets_max: 40_000_000, sales_max: 60_000_000, employees_max: 5 }
      },
      "other" => {
        large: { assets_min: 15_000_000_000, sales_min: 15_000_000_000 },
        small: { assets_max: 50_000_000, sales_max: 80_000_000, employees_max: 5 }
      }
    }.freeze

    DISCRETION_RATES = {
      large: 0.7,
      medium: 0.6,
      small: 0.5
    }.freeze

    Result = Struct.new(
      :size_code,
      :size_label,
      :l_ratio,
      :discretion_rate,
      :industry_type_label,
      :judgment_basis,
      keyword_init: true
    )

    def initialize(total_assets:, annual_sales:, employees:, industry_type:)
      @total_assets = total_assets.to_i
      @annual_sales = annual_sales.to_i
      @employees = employees.to_i
      @industry_type = industry_type.to_s
      @industry_type = "other" unless INDUSTRY_TYPES.key?(@industry_type)
    end

    def call
      size_code, size_label, basis = determine_size_category
      l_ratio = size_code == :medium ? determine_l_ratio : nil

      Result.new(
        size_code: size_code,
        size_label: size_label,
        l_ratio: l_ratio,
        discretion_rate: DISCRETION_RATES.fetch(size_code),
        industry_type_label: INDUSTRY_TYPES.fetch(@industry_type),
        judgment_basis: basis
      )
    end

    def self.js_config
      {
        employeeLargeThreshold: EMPLOYEE_LARGE_THRESHOLD,
        employeeLargeAssetSalesMin: EMPLOYEE_LARGE_ASSET_SALES_MIN,
        criteria: SIZE_CRITERIA.transform_values { |tier| criteria_to_js(tier) },
        lAssetTiers: l_tiers_to_js(L_ASSET_TIERS, :assets_min),
        lSalesTiers: l_tiers_to_js(L_SALES_TIERS, :sales_min, :sales_max)
      }
    end

    def self.l_tiers_to_js(tiers_by_industry, *amount_keys)
      tiers_by_industry.transform_values do |tiers|
        tiers.map do |tier|
          row = { "ratio" => tier[:ratio] }
          row["employees_min"] = tier[:employees_min] if tier.key?(:employees_min)
          amount_keys.each do |key|
            row[key.to_s] = to_sen(tier[key]) if tier.key?(key)
          end
          row
        end
      end
    end

    def self.criteria_to_js(tier)
      {
        "large" => {
          "assets_min" => to_sen(tier[:large][:assets_min]),
          "sales_min" => to_sen(tier[:large][:sales_min])
        },
        "small" => {
          "assets_max" => to_sen(tier[:small][:assets_max]),
          "sales_max" => to_sen(tier[:small][:sales_max]),
          "employees_max" => tier[:small][:employees_max]
        }
      }
    end

    def self.to_sen(yen)
      yen / 1000
    end

    private

    def determine_size_category
      if @employees >= EMPLOYEE_LARGE_THRESHOLD
        return [:large, "大会社", "従業員数が#{EMPLOYEE_LARGE_THRESHOLD}人以上のため大会社"]
      end

      if large_company_by_assets_and_sales?
        return [:large, "大会社", "総資産価額・取引金額が大会社の基準を満たすため大会社"]
      end

      if small_company?
        return [:small, "小会社", "総資産価額・取引金額・従業員数が小会社の基準に該当するため小会社"]
      end

      [:medium, "中会社", "大会社・小会社のいずれにも該当しないため中会社"]
    end

    def large_company_by_assets_and_sales?
      return false if @employees < EMPLOYEE_LARGE_ASSET_SALES_MIN

      c = SIZE_CRITERIA.fetch(@industry_type).fetch(:large)
      @total_assets >= c[:assets_min] && @annual_sales >= c[:sales_min]
    end

    def small_company?
      c = SIZE_CRITERIA.fetch(@industry_type).fetch(:small)
      column1 = @total_assets < c[:assets_max] || @employees <= c[:employees_max]
      column2 = @annual_sales < c[:sales_max]

      column1 && column2
    end

    def determine_l_ratio
      [l_ratio_from_assets, l_ratio_from_sales].max
    end

    def l_ratio_from_assets
      L_ASSET_TIERS.fetch(@industry_type).each do |tier|
        next unless @total_assets >= tier[:assets_min] && @employees >= tier[:employees_min]

        return tier[:ratio]
      end

      0.0
    end

    def l_ratio_from_sales
      tiers = L_SALES_TIERS.fetch(@industry_type)
      tiers.each_with_index do |tier, index|
        next unless sales_in_l_tier?(@annual_sales, tier, highest_tier: index.zero?)

        return tier[:ratio]
      end

      0.0
    end

    # 通達の「○億円以上△億円未満」は区間の重複を避けるため下位区分は上限未満。
    # 最上位区分のみ、入力単位（千円）の上限値ちょうど（例: 15億円）を含める。
    def sales_in_l_tier?(sales, tier, highest_tier:)
      return false unless sales >= tier[:sales_min]

      if highest_tier
        sales <= tier[:sales_max]
      else
        sales < tier[:sales_max]
      end
    end
  end
end
