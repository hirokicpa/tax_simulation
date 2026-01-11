

class Simulations::IncorporationController < ApplicationController
    def index
    end
    
    def variables
        @taxableincome = incorporation_params[:taxableincome].to_i # 個人課税所得額
        @income_deduction = incorporation_params[:total_income_deduction].to_i  #所得控除合計
        @taxableincome_after_deduction = (@taxableincome - @income_deduction).to_i
        @blue_return = incorporation_params[:blue_return].to_i#青色申告特別控除額
        @corporate_taxableincome = incorporation_params[:transferincome].to_i # 法人化による個人所得の法人移転額(
        @salary = incorporation_params[:salary].to_i # 法人からの役員報酬額
        @corporate_taxableincome_after_salary = (@corporate_taxableincome - @salary *12 ).to_i  #法人化後の給与控除後の課税所得
        @taxableincome_deduction_transferincome = (@taxableincome - @corporate_taxableincome).to_i #法人に移転した後の個人所得
        
        # 基礎控除の計算（令和7年分基準）
        @basic_deduction = calculate_basic_deduction(@taxableincome)
    end
    
   

    # 所得税（復興所得税含む）　法人化前
    def individual_income_tax
      variables
      @result_income = 0
      if @taxableincome_after_deduction && @taxableincome_after_deduction >= 0
        @result_income = (income_tax(@taxableincome_after_deduction) * 1.021).floor
      end
    end

    # 個人住民税　前
    def individual_resident_tax
      variables
      @result_individual_resident = 0
      if @taxableincome_after_deduction && @taxableincome_after_deduction >= 0
        @result_individual_resident = ((@taxableincome_after_deduction + 5) * 0.1).floor
      end
    end

    # 個人事業税　前
    def individual_business_tax
      variables
      @result_individual_business = 0
      if @taxableincome && (@taxableincome - 290) >= 0
        @result_individual_business = ((@taxableincome - 290 ) * 0.05).floor
      end
    end


     # 所得税（復興所得税含む）　法人化　後
  def individual_income_after_tax
    variables
    @result_income_after = 0
    @taxableincome_after_corporate = 0
    @salary_year = 0
    @salary_deduction = 0
    @salary_income = 0
    
    if @taxableincome_deduction_transferincome && @salary && (@taxableincome_deduction_transferincome + @salary * 12) >= 160
      @salary_year = @salary * 12
      @salary_deduction = salary_deduction(@salary_year).floor
      @salary_income = (@salary_year - @salary_deduction).floor
      @taxableincome_after_corporate = ((@taxableincome_deduction_transferincome + @salary_income) - @income_deduction).floor
      @result_income_after = (income_tax(@taxableincome_after_corporate) * 1.021).floor
    end
  end
    
   # 個人住民税　 後
  def individual_resident_after_tax
    variables
    @result_individual_resident_after = 0
    if @taxableincome_after_corporate && @taxableincome_after_corporate >= 38
      @result_individual_resident_after = ((@taxableincome_after_corporate + 5) * 0.1).floor
    end
  end

  # 個人事業税 後　
  def individual_business_after_tax
    variables
    @result_individual_business_after = 0
    if @taxableincome_deduction_transferincome && (@taxableincome_deduction_transferincome - 290) >= 0
      @result_individual_business_after = ((@taxableincome_deduction_transferincome - 290 ) * 0.05).floor
    end
  end

   # 法人税（地方法人税含む) 法人化後
    def corporate_tax
      variables
      # 初期化
      @result_houjinzei = 0
      @houjinzei_nation = 0
      @houjinzei_local = 0
      
      return if @corporate_taxableincome_after_salary.nil? || @corporate_taxableincome_after_salary <= 0
      
      if @corporate_taxableincome_after_salary > 0 && @corporate_taxableincome_after_salary <=800
        @houjinzei_nation = (@corporate_taxableincome_after_salary *0.15).floor
        @houjinzei_local = (@houjinzei_nation * 0.044).floor
        @result_houjinzei = @houjinzei_nation + @houjinzei_local
      elsif @corporate_taxableincome_after_salary > 800
        @houjinzei_nation = (800 * 0.15 + (@corporate_taxableincome_after_salary - 800) * 0.232).floor
        @houjinzei_local = (@houjinzei_nation * 0.044).floor
        @result_houjinzei = @houjinzei_nation + @houjinzei_local
      end    
    end

    # 住民税(均等割除く） 法人化後
    def resident_tax
      variables
      # 初期化
      @result_resident = 0
      
      return if @result_houjinzei.nil? || @result_houjinzei <= 0
      
      if @result_houjinzei > 0 && @result_houjinzei < 1000
        @result_resident = (@result_houjinzei * 0.129).floor
      elsif @result_houjinzei >= 1000
        @result_resident = (@result_houjinzei * 0.163).floor
      end
    end


    # 事業税(所得割） 法人化後
    def business_tax
      variables
      # 初期化
      @business_tax_sum = 0
      @business_tax_local = 0
      @sum_business_tax = 0
      @local_corporate_tax = 0
      
      return if @corporate_taxableincome_after_salary.nil? || @corporate_taxableincome_after_salary <= 0
      
      if @corporate_taxableincome_after_salary <= 2500
        if @corporate_taxableincome_after_salary > 0 && @corporate_taxableincome_after_salary <= 400
          @business_tax_sum = (@corporate_taxableincome_after_salary * 0.035).floor
        elsif @corporate_taxableincome_after_salary >400 && @corporate_taxableincome_after_salary <= 800
          @business_tax_sum = ((@corporate_taxableincome_after_salary - 400 ) * 0.053 + 400 * 0.035).floor
        elsif @corporate_taxableincome_after_salary > 800 
          @business_tax_sum = ((@corporate_taxableincome_after_salary - 800) * 0.07 + 400 * 0.035 + 400 * 0.053).floor
        end
        @business_tax_local = (@business_tax_sum * 0.432).floor
        @sum_business_tax = @business_tax_sum + @business_tax_local
      elsif @corporate_taxableincome_after_salary > 2500
        @business_tax_sum = ((@corporate_taxableincome_after_salary - 800) * 0.0748 + 400 * 0.0375 + 400 * 0.05665).floor
        @business_tax_standard_sum = ((@corporate_taxableincome_after_salary - 800) * 0.07 + 400 * 0.035 + 400 * 0.053).floor
        @business_tax_local = (@business_tax_standard_sum * 0.432).floor
        @sum_business_tax = @business_tax_sum + @business_tax_local
      end
      
      # ビューで使用される変数名に合わせる
      @local_corporate_tax = @business_tax_local
    end
    
    
    def income_tax(sum)
      result = 0
      if sum <= 195
        result = (sum * 0.05).to_f
      elsif sum > 195 && sum <= 330
        result = ((sum * 0.1) - 9.75).to_f
      elsif sum > 330 && sum <= 695
        result = ((sum * 0.2) - 42.75).to_f
      elsif sum > 695 && sum <= 900
        result = ((sum * 0.23) - 63.6).to_f
      elsif sum > 900 && sum <= 1800
        result = ((sum * 0.33) - 153.6).to_f
      elsif sum > 1800 && sum <= 4000
        result = ((sum * 0.4) - 279.6).to_f
      elsif sum > 4000
        result = ((sum * 0.45) - 479.6).to_f
      end
      return result
    end
    
    def salary_deduction(sum)
      sum = sum.to_f
      return 0 if sum <= 0  # ★これを追加（0以下は控除なし）
      result = 0
      if sum <= 190
        result = 65
      elsif sum > 190 && sum <= 360
        result = ((sum * 0.3) + 8).to_f
      elsif sum > 360 && sum <= 660
        result = ((sum * 0.2) + 44).to_f
      elsif sum > 660 && sum <= 850
        result = ((sum * 0.1) + 110).to_f
      elsif sum > 850
        result = 195
      end
      return result
    end
    
    def result_tax
        variables
        individual_income_after_tax
        corporate_tax
        resident_tax
        business_tax
        individual_business_tax
        individual_income_tax
        individual_resident_tax
        individual_business_tax
        individual_resident_after_tax
        individual_business_after_tax
        respond_to do |format|
          format.html { render partial: 'result' }
          format.js
        end
    end

    private
    def incorporation_params
      params.permit(:utf8, :commit, :taxableincome, :total_income_deduction, :blue_return, :transferincome, :salary,
                   :breakdown1, :breakdown2, :breakdown3, :breakdown4, :breakdown5, :breakdown6,
                   :breakdown7, :breakdown8, :breakdown9, :breakdown10, :breakdown11, :breakdown12)
    end

    # 基礎控除の計算（令和7年分基準）
    def calculate_basic_deduction(income)
      case income
      when 0..132
        95 # 132万円以下: 95万円
      when 133..336
        58 # 132万円超 336万円以下: 58万円
      when 337..489
        68 # 336万円超 489万円以下: 68万円
      when 490..655
        63 # 489万円超 655万円以下: 63万円
      when 656..2350
        58 # 655万円超2,350万円以下: 58万円
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
end