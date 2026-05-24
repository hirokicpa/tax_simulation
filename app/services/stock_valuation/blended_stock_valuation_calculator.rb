# frozen_string_literal: true

module StockValuation
  # 第179条に基づく類似業種比準価額と純資産価額（相続税評価額）の併用
  class BlendedStockValuationCalculator
    SMALL_COMPANY_BLEND_RATIO = 0.5

    Result = Struct.new(
      :inheritance_net_assets,
      :inheritance_net_asset_per_share,
      :similar_industry_per_share,
      :l_ratio,
      :per_share_valuation,
      :total_valuation,
      :method_label,
      :calculation_steps,
      keyword_init: true
    )

    def initialize(similar_industry_per_share:, inheritance_net_assets:, company_size:, issued_shares:)
      @similar = similar_industry_per_share.to_i
      @inheritance_net_assets = inheritance_net_assets.to_i
      @company_size = company_size
      @issued_shares = issued_shares.to_i
      @inheritance_per_share = per_share_from_total(@inheritance_net_assets)
    end

    def call
      steps = []
      steps << "1株当たりの純資産価額（相続税評価額）= #{yen(@inheritance_net_assets)} ÷ #{number_with_delimiter(@issued_shares)}株 = #{yen(@inheritance_per_share)}"

      l_ratio = @company_size.l_ratio
      method_label, per_share = calculate_per_share(l_ratio, steps)

      Result.new(
        inheritance_net_assets: @inheritance_net_assets,
        inheritance_net_asset_per_share: @inheritance_per_share,
        similar_industry_per_share: @similar,
        l_ratio: l_ratio,
        per_share_valuation: per_share,
        total_valuation: per_share * @issued_shares,
        method_label: method_label,
        calculation_steps: steps
      )
    end

    private

    def per_share_from_total(total)
      return 0 if @issued_shares <= 0

      (total.to_f / @issued_shares).floor
    end

    def calculate_per_share(l_ratio, steps)
      inheritance = @inheritance_per_share

      case @company_size.size_code
      when :medium
        l = l_ratio || 0
        per_share = (@similar * l + inheritance * (1 - l)).floor
        steps << "中会社の評価（第179条）= 類似業種比準価額(#{yen(@similar)}) × L(#{l}) + 1株当たり純資産価額(#{yen(inheritance)}) × (1-L)(#{format('%.2f', 1 - l)}) = #{yen(per_share)}"
        ["中会社（類似業種比準価額×L + 純資産価額×(1-L)）", per_share]
      when :small
        blend = (@similar * SMALL_COMPANY_BLEND_RATIO + inheritance * SMALL_COMPANY_BLEND_RATIO).floor
        steps << "小会社の原則評価 = 1株当たり純資産価額（相続税評価額）#{yen(inheritance)}"
        steps << "選択による折衷（L=0.50）= 類似業種比準価額(#{yen(@similar)}) × 0.5 + 1株当たり純資産価額(#{yen(inheritance)}) × 0.5 = #{yen(blend)}"
        steps << "※実務では原則方式と折衷方式のいずれか低い方等を選択します（本シミュレーションでは折衷額を参考表示）"
        ["小会社（純資産価額・折衷参考）", blend]
      else
        steps << "大会社の評価 = 類似業種比準価額 #{yen(@similar)}（純資産価額は選択時に使用）"
        ["大会社（類似業種比準価額）", @similar]
      end
    end

    def yen(value, precision: 0)
      ActiveSupport::NumberHelper.number_to_delimited(value.round(precision))
    end

    def number_with_delimiter(value)
      ActiveSupport::NumberHelper.number_to_delimited(value)
    end
  end
end
