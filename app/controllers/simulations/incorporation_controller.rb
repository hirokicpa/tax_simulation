class Simulations::IncorporationController < ApplicationController
    def index
    end
    
    def variables
       @individual_taxable_income = incorporation_params[:annual_income].to_f - incorporation_params[:annual_expense].to_f 
       @income_deduction = incorporation_params[:income_deduction].to_f
       @taxable_income_after_deduction = @individual_taxable_income - incorporation_params[:special_deduction].to_f - incorporation_params[:income_deduction].to_f
       @year_salary = incorporation_params[:month_salary].to_f * 12
       @corporate_taxable_income_except_salary = @individual_taxable_income - @year_salary
    end
    
     # 所得税 法人化前
    def individual_income_tax_before_incorporation
      variables
      if @taxable_income_after_deduction >= 0
        @result_income_tax = (income_tax(@taxable_income_after_deduction) * 1.021).floor
      else
        @result_income_tax = 0
      end
    end
    
     # 所得税 法人化後
    def individual_income_tax_after_incorporation
      variables
      if  @year_salary >= 55
          @salary_deduction = salary_deduction(@year_salary).floor
          @salary_income_after_deduction = @year_salary - @salary_deduction >= 0 ? (@year_salary - @salary_deduction).floor : 0
          @taxable_income_after_incorporation = (@salary_income_after_deduction - @income_deduction).floor
          if @taxable_income_after_incorporation >= 0
            @result_income_tax_after = (income_tax(@taxable_income_after_incorporation) * 1.021).floor
          else
            @result_income_tax_after = 0
          end
      else
          @result_income_tax_after = 0
      end
    end
    
    # 個人住民税 法人化前
    def individual_resident_tax_before_incorporation
      variables
      if @taxable_income_after_deduction >= 0
        @result_individual_resident_tax = ((@taxable_income_after_deduction) * 0.1).floor
      else
        @result_individual_resident_tax = 0
      end
    end
    
     # 個人住民税 法人化後 
    def individual_resident_tax_after_incorporation
      variables
      @salary_deduction = salary_deduction(@year_salary).floor
      @salary_income_after_deduction = (@year_salary - @salary_deduction).floor
      @taxable_income_after_incorporation = (@salary_income_after_deduction - @income_deduction).floor
      @result_individual_resident_tax_after = @taxable_income_after_incorporation >= 0 ? ((@taxable_income_after_incorporation) * 0.1).floor : 0
    end
    
    # 個人事業税 法人化前
    def individual_business_tax_before_incorporation
      variables
      if (@individual_taxable_income - 290) >= 0
        @result_individual_business_tax = ((@individual_taxable_income - 290 ) * 0.05).floor
      else
        @result_individual_business_tax = 0
      end
    end
    
    
    # 法人税 法人化後
    def corporate_tax
      variables
      if @corporate_taxable_income_except_salary >= 0 && @corporate_taxable_income_except_salary <= 800
         @national_corporate_tax = (@corporate_taxable_income_except_salary * 0.15).floor
         @local_corporate_tax = (@national_corporate_tax * 0.044).floor
         @result_corporate_tax = @national_corporate_tax + @local_corporate_tax
      elsif @corporate_taxable_income_except_salary > 800
         @national_corporate_tax = (800 * 0.15 + (@corporate_taxable_income_except_salary - 800) * 0.232).floor
         @local_corporate_tax = (@national_corporate_tax * 0.044).floor
         @result_corporate_tax = @national_corporate_tax + @local_corporate_tax
      else
         @result_corporate_tax = 0
      end
    end
      
       # 住民税(均等割除く) 法人化後
    def resident_tax
      variables
      corporate_tax
      if @national_corporate_tax >= 0 && @national_corporate_tax < 1000
         @result_resident_tax = (@national_corporate_tax * 0.129).floor
      elsif @national_corporate_tax >= 1000
         @result_resident_tax = (@national_corporate_tax * 0.163).floor
      else
        @result = 0
      end
    end
    
      # 事業税(所得割と地方法人特別税) @business_tax_incomeが所得割、@business_tax_localが地方法人特別税
    def business_tax
      variables
        if @corporate_taxable_income_except_salary <= 2500
          if @corporate_taxable_income_except_salary > 0 && @corporate_taxable_income_except_salary <= 400
            @business_tax_income = (@corporate_taxable_income_except_salary * 0.035).floor
          elsif @corporate_taxable_income_except_salary > 400 && @corporate_taxable_income_except_salary <= 800
            @business_tax_income = ((@corporate_taxable_income_except_salary - 400 ) * 0.053 + 400 * 0.035).floor
          elsif @corporate_taxable_income_except_salary > 800
            @business_tax_income = ((@corporate_taxable_income_except_salary - 800) * 0.07 + 400 * 0.035 + 400 * 0.053).floor
          else
            @business_tax_income = 0
            @business_tax = 0
          end
            @business_tax_local = (@business_tax_income * 0.432).floor
            @sum_business_tax = @business_tax_income + @business_tax_local
        elsif @corporate_taxable_income_except_salary > 2500
            @business_tax_income = ((@corporate_taxable_income_except_salary - 800) * 0.0748 + 400 * 0.0375 + 400 * 0.05665).floor
            @business_tax_standard_sum = ((@corporate_taxable_income_except_salary - 800) * 0.067 + 400 * 0.034 + 400 * 0.051).floor
            @business_tax_local = (@business_tax_standard_sum * 0.432).floor
            @sum_business_tax = @business_tax_income + @business_tax_local
        end
    end
    
       # 合計
    def sum_tax
      variables
      individual_income_tax_before_incorporation
      individual_income_tax_after_incorporation
      individual_resident_tax_before_incorporation
      individual_resident_tax_after_incorporation
      individual_business_tax_before_incorporation
      corporate_tax
      resident_tax
      business_tax
      @sum_tax_before = @result_income_tax + @result_individual_resident_tax + @result_individual_business_tax
      @sum_tax_after = @result_income_tax_after + @result_individual_resident_tax_after + 0 + @result_corporate_tax + @result_resident_tax + @sum_business_tax
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
        individual_income_tax_before_incorporation
        individual_income_tax_after_incorporation
        individual_resident_tax_before_incorporation
        individual_resident_tax_after_incorporation
        individual_business_tax_before_incorporation
        corporate_tax
        resident_tax
        business_tax
        sum_tax
        render :index
    end

    private
    def incorporation_params
        params.permit(:utf8, :commit, :annual_income, :annual_expense, :special_deduction, :income_deduction, :month_salary)
    end
end