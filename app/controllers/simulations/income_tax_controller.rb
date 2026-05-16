class Simulations::IncomeTaxController < ApplicationController
  def index
  end

  def result_tax
    @income = income_tax_params[:income].to_i
    @total_income_deduction = income_tax_params[:total_income_deduction].to_i
    
    # 基礎控除の計算（令和8年分基準）
    @basic_deduction = calculate_basic_deduction(@income)
    
    # 基礎控除以外の所得控除 = 所得控除合計 - 基礎控除
    @other_income_deduction = @total_income_deduction - @basic_deduction
    
    # 課税される所得金額 = 所得 - 所得控除合計（1,000円未満切り捨て）
    @taxable_income = ((@income - @total_income_deduction) * 10000 / 1000).floor * 1000
    
    # 所得税額の計算（速算表を使用）
    @income_tax = calculate_income_tax(@taxable_income)
    
    # 税率の取得
    @tax_rate = get_tax_rate(@taxable_income)
    
    render :index
  end

  private

  def income_tax_params
    params.permit(:income, :total_income_deduction, :breakdown1, :breakdown2, :breakdown3, :breakdown4, :breakdown5, :breakdown6, :breakdown7, :breakdown8, :breakdown9, :breakdown10, :breakdown11, :breakdown12)
  end

  # 基礎控除の計算（令和8年分基準）
  def calculate_basic_deduction(income)
    case income
    when 0..489
      104 # 489万円以下: 104万円
    when 490..655
      67 # 489万円超 655万円以下: 67万円
    when 656..2350
      62 # 655万円超2,350万円以下: 62万円
    when 2351..2400
      48 # 2,350万円超2,400万円以下: 48万円
    when 2401..2450
      32 # 2,400万円超2,450万円以下: 32万円
    when 2451..2500
      16 # 2,450万円超2,500万円以下: 16万円
    else
      0 # 2,500万円超: 0円
    end
  end

  # 所得税額の計算（速算表）
  def calculate_income_tax(taxable_income)
    return 0 if taxable_income < 1000
    
    case taxable_income
    when 1000..1949999
      (taxable_income * 0.05).floor
    when 1950000..3299999
      (taxable_income * 0.10 - 97500).floor
    when 3300000..6949999
      (taxable_income * 0.20 - 427500).floor
    when 6950000..8999999
      (taxable_income * 0.23 - 636000).floor
    when 9000000..17999999
      (taxable_income * 0.33 - 1536000).floor
    when 18000000..39999999
      (taxable_income * 0.40 - 2796000).floor
    else
      (taxable_income * 0.45 - 4796000).floor
    end
  end

  # 税率の取得
  def get_tax_rate(taxable_income)
    return 0 if taxable_income < 1000
    
    case taxable_income
    when 1000..1949999
      5
    when 1950000..3299999
      10
    when 3300000..6949999
      20
    when 6950000..8999999
      23
    when 9000000..17999999
      33
    when 18000000..39999999
      40
    else
      45
    end
  end
end
