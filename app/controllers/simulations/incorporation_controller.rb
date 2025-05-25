

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
    end
    
   

    # 所得税（復興所得税含む）　法人化前
    def individual_income_tax
      variables
      if @taxableincome_after_deduction >= 0
        @result_income = (income_tax(@taxableincome_after_deduction) * 1.021).floor
      else
        @result_income = 0
      end
    end

    # 個人住民税　前
    def individual_resident_tax
      variables
      if @taxableincome_after_deduction >= 0
        @result_individual_resident = ((@taxableincome_after_deduction + 5) * 0.1).floor
      else
        @result_individual_resident = 0
      end
    end

    # 個人事業税　前
    def individual_business_tax
      variables
      if (@taxableincome -290) >= 0
        @result_individual_business = ((@taxableincome - 290 ) * 0.05).floor
      else
        @result_individual_business = 0
      end
    end


     # 所得税（復興所得税含む）　法人化　後
  def individual_income_after_tax
    variables
    if  (@taxableincome_deduction_transferincome + @salary * 12) >= 103
      @salary_year = @salary * 12
      @salary_deduction = salary_deduction(@salary_year).floor
      @salary_income = (@salary_year - @salary_deduction).floor
      @taxableincome_after_corporate = ((@taxableincome_deduction_transferincome + @salary_income) - @income_deduction).floor
      @result_income_after = (income_tax(@taxableincome_after_corporate) * 1.021).floor
    else 
        @result_income_after = 0
    end
  end
    
   # 個人住民税　 後
  def individual_resident_after_tax
    variables
    if @taxableincome_after_corporate >= 38
      @result_individual_resident_after = ((@taxableincome_after_corporate + 5) * 0.1).floor
    else
      @result_individual_resident_after = 0
    end
  end

  # 個人事業税 後　
  def individual_business_after_tax
    variables
    if (@taxableincome_deduction_transferincome - 290 ) >= 0
      @result_individual_business_after = ((@taxableincome_deduction_transferincome - 290 ) * 0.05).floor
    else
      @result_individual_business_after = 0
    end
  end

   # 法人税（地方法人税含む) 法人化後
    def corporate_tax
      variables
      @corporate_taxable_income_after_salary ||= 0
      if @corporate_taxableincome_after_salary > 0 && @corporate_taxableincome_after_salary <=800
        @houjinzei_nation = (@corporate_taxableincome_after_salary *0.15).floor
        @houjinzei_local = (@houjinzei_nation * 0.044).floor
        @result_houjinzei = @houjinzei_nation + @houjinzei_local
      elsif @corporate_taxableincome_after_salary > 800
        @houjinzei_nation = (800 * 0.15 + (@corporate_taxableincome_after_salary - 800) * 0.232).floor
        @houjinzei_local = (@houjinzei_nation * 0.044).floor
        @result_houjinzei = @houjinzei_nation + @houjinzei_local
      else 
        @result_houjinzei = 0
      end    
    end

    # 住民税(均等割除く） 法人化後
    def resident_tax
      variables
      if @result_houjinzei > 0 && @result_houjinzei < 1000
        @result_resident = (@result_houjinzei * 0.129).floor
      elsif @result_houjinzei >= 1000
        @result_resident = (@result_houjinzei * 0.163).floor
      else 
        @result_resident = 0
      end
    end


    # 事業税(所得割） 法人化後
    def business_tax
      variables
      if @corporate_taxableincome_after_salary <= 2500
        if @corporate_taxableincome_after_salary > 0 && @corporate_taxableincome_after_salary <= 400
          @business_tax_sum = (@corporate_taxableincome_after_salary * 0.035).floor
        elsif @corporate_taxableincome_after_salary >400 && @corporate_taxableincome_after_salary <= 800
          @business_tax_sum = ((@corporate_taxableincome_after_salary - 400 ) * 0.053 + 400 * 0.035).floor
        elsif @corporate_taxableincome_after_salary > 800 
          @business_tax_sum = ((@corporate_taxableincome_after_salary - 800) * 0.07 + 400 * 0.035 + 400 * 0.053).floor
        else 
          @business_tax_sum = 0
        end
        @business_tax_local = (@business_tax_sum * 0.432).floor
        @sum_business_tax = @business_tax_sum + @business_tax_local
      elsif @corporate_taxableincome_after_salary > 2500
        @business_tax_sum = ((@corporate_taxableincome_after_salary - 800) * 0.0748 + 400 * 0.0375 + 400 * 0.05665).floor
        @business_tax_standard_sum = ((@corporate_taxableincome_after_salary - 800) * 0.07 + 400 * 0.035 + 400 * 0.053).floor
        @business_tax_local = (@business_tax_standard_sum * 0.432).floor
        @sum_business_tax = @business_tax_sum + @business_tax_local
      end
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
      result = 0
      if sum <= 162.5
        result = 55
      elsif sum > 162.5 && sum <= 180
        result = ((sum * 0.4) - 10).to_f
      elsif sum > 180 && sum <= 360
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
end