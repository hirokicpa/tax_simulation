class Simulations::BusinessSuccessionTaxController < ApplicationController
    require 'bigdecimal'
    require 'bigdecimal/util'
  
    def index
      @errors = []
      
      # パラメータの初期化
      @marital_status = params[:marital_status] || "0"
      @legal_heir = params[:legal_heir] || "0"
      @children_count = params[:children_count] || "0"
      @siblings_count = params[:siblings_count] || "0"
      
      # 後継者の遺産取得割合の計算
      if params[:total_heritage].present? && params[:total_heritage].to_f > 0
        total_heritage = params[:total_heritage].to_s.gsub(',', '').to_f
        heir_special_stock_value = (params[:heir_special_stock_value] || 0).to_s.gsub(',', '').to_f
        other_heir_get_heritage = (params[:other_heir_get_heritage] || 0).to_s.gsub(',', '').to_f
        
        @result_heir_rate_show = ((heir_special_stock_value + other_heir_get_heritage) / total_heritage * 100).round(2)
        @marital_rate_show = (100 - @result_heir_rate_show).round(2)
        @marital_rate_disabled = false
      else
        @result_heir_rate_show = 0
        @marital_rate_show = params[:marital_rate] || ""
        @marital_rate_disabled = true
      end
      
      # 計算実行（パラメータが存在する場合）
      if params[:commit].present?
        # バリデーション
        if params[:total_heritage].blank? || params[:total_heritage].to_f <= 0
          @errors << "現在の遺産総額を入力してください。"
        end
        if params[:heir_special_stock_value].blank? || params[:heir_special_stock_value].to_f < 0
          @errors << "特例適応対象株式の評価額を入力してください。"
        end
        if params[:applied_condition].blank?
          @errors << "事業承継税制の適用要件を選択してください。"
        end
        if params[:applied_condition] == "1"
          @errors << "事業承継税制の適用要件を満たしていない場合は、このシミュレーションは適用できません。"
        end
        if @marital_status == "0" && params[:marital_rate].blank?
          @errors << "配偶者の遺産取得割合を入力してください。"
        end
        if @legal_heir == "0" && (@children_count.blank? || @children_count.to_i == 0)
          @errors << "子供の人数を選択してください。"
        end
        if @legal_heir == "2" && (@siblings_count.blank? || @siblings_count.to_i == 0)
          @errors << "兄弟姉妹の人数を選択してください。"
        end
        
        # エラーがなければ計算実行
        if @errors.empty?
          variables
          @result_succession = step1_result_tax
          @result_heir_succession = step1_heir_succession
          tax_grace_amount
          @result_tax_grace_amount = @tax_grace_amount
        end
      end
      
      render 'simulations/business_succession/index'
    end
  
    def variables
      @max_tax_limit = 16000
      @total_heritage = permit_params[:total_heritage].to_s.gsub(',', '').to_f
      @heir_special_stock_value = permit_params[:heir_special_stock_value].to_s.gsub(',', '').to_f
      @other_heir_get_heritage = permit_params[:other_heir_get_heritage].to_s.gsub(',', '').to_f
      @legal_heir     = permit_params[:legal_heir]
      @marital_status = permit_params[:marital_status]
      @children_count = permit_params[:children_count].to_i
      @siblings_count = permit_params[:siblings_count].to_i
      @marital_rate   = (permit_params[:marital_rate].to_f / 100).to_d
  
      # step1 課税対象金額（万円ベース）
      @heir_mate_children_step1  = @total_heritage - (3000 + 600 * (@children_count + 1))
      @heir_mate_siblings_step1  = @total_heritage - (3000 + 600 * (@siblings_count + 1))
      @heir_children_step1       = @total_heritage - (3000 + 600 * @children_count)
      @heir_siblings_step1       = @total_heritage - (3000 + 600 * @siblings_count)
  
      # step2 課税対象金額（万円ベース）
      @heir_mate_children_step2  = @total_heritage - @other_heir_get_heritage - (3000 + 600 * (@children_count + 1))
      @heir_mate_siblings_step2  = @total_heritage - @other_heir_get_heritage - (3000 + 600 * (@siblings_count + 1))
      @heir_children_step2       = @total_heritage - @other_heir_get_heritage - (3000 + 600 * @children_count)
      @heir_siblings_step2       = @total_heritage - @other_heir_get_heritage - (3000 + 600 * @siblings_count)
    end
  
    def step1_method_A
      variables
      case @legal_heir
      when "0" # 配偶者＆子
        mate_sum  = @heir_mate_children_step1 / 2
        child_sum = (@heir_mate_children_step1 - mate_sum) / @children_count
        succession_tax(mate_sum) + succession_tax(child_sum) * @children_count
      when "2" # 配偶者＆兄弟姉妹
        mate_sum     = @heir_mate_siblings_step1 * 3 / 4
        sibling_sum  = (@heir_mate_siblings_step1 - mate_sum) / @siblings_count
        (succession_tax(mate_sum) + succession_tax(sibling_sum) * @siblings_count) * 1.2
      end
    end
  
    def step1_method_B
      variables
      case @legal_heir
      when "0" # 子のみ
        child_sum = @heir_children_step1 / @children_count
        succession_tax(child_sum) * @children_count
      when "2" # 兄弟姉妹のみ
        sibling_sum = @heir_siblings_step1 / @siblings_count
        succession_tax(sibling_sum) * @siblings_count * 1.2
      else
        0
      end
    end
  
    def step2_method_A
      variables
      case @legal_heir
      when "0" # 配偶者＆子
        mate_sum  = @heir_mate_children_step2 / 2
        child_sum = (@heir_mate_children_step2 - mate_sum) / @children_count
        succession_tax(mate_sum) + succession_tax(child_sum) * @children_count
      when "2" # 配偶者＆兄弟姉妹
        mate_sum     = @heir_mate_siblings_step2 * 3 / 4
        sibling_sum  = (@heir_mate_siblings_step2 - mate_sum) / @siblings_count
        (succession_tax(mate_sum) + succession_tax(sibling_sum) * @siblings_count) * 1.2
      end
    end
  
    def step2_method_B
      variables
      case @legal_heir
      when "0" # 子のみ
        child_sum = @heir_children_step2 / @children_count
        succession_tax(child_sum) * @children_count
      when "2" # 兄弟姉妹のみ
        sibling_sum = @heir_siblings_step2 / @siblings_count
        succession_tax(sibling_sum) * @siblings_count * 1.2
      else
        0
      end
    end
  
    def succession_tax(sum)
      result = 0
      if sum <= 1000
        result = sum * 0.1
      elsif sum <= 3000
        result = (sum * 0.15) - 50
      elsif sum <= 5000
        result = (sum * 0.2) - 200
      elsif sum <= 10000
        result = (sum * 0.3) - 700
      elsif sum <= 20000
        result = (sum * 0.40) - 1700
      elsif sum <= 30000
        result = (sum * 0.45) - 2700
      elsif sum <= 60000
        result = (sum * 0.50) - 4200
      else
        result = (sum * 0.55) - 7200
      end
      result
    end
  
    def step1_result_tax
      variables
      calc = lambda {
        if @marital_status == "0"
          step1_method_A
        else
          step1_method_B
        end
      }
  
      if @marital_status == "0"
        return 0 if @heir_mate_children_step1 < 0 || @heir_mate_siblings_step1 < 0
        calc.call
      else
        return 0 if @heir_children_step1 < 0 || @heir_siblings_step1 < 0
        calc.call
      end
    end
  
    def step2_result_tax
      variables
      calc = lambda {
        if @marital_status == "0"
          step2_method_A
        else
          step2_method_B
        end
      }
  
      if @marital_status == "0"
        return 0 if @heir_mate_children_step2 < 0 || @heir_mate_siblings_step2 < 0
        calc.call
      else
        return 0 if @heir_children_step2 < 0 || @heir_siblings_step2 < 0
        calc.call
      end
    end
  
    def step1_heir_succession
      variables
      (step1_result_tax * (@heir_special_stock_value + @other_heir_get_heritage) / @total_heritage).round(3).floor
    end
  
    def step2_heir_succession
      variables
      (step2_result_tax * @heir_special_stock_value / (@total_heritage - @other_heir_get_heritage)).round(3).floor
    end
  
    def tax_grace_amount
      if step1_heir_succession <= step2_heir_succession
        @tax_grace_amount = step1_heir_succession
      else
        @tax_grace_amount = step2_heir_succession
      end
    end
  
    # === API ===
  
    def result_heir_rate
      variables
      if @total_heritage != 0
        result_heir_rate = ((@heir_special_stock_value.to_d + @other_heir_get_heritage.to_d) / @total_heritage.to_d) * 100
        result_marital_rate = 100 - result_heir_rate
        render json: { result_heir_rate: result_heir_rate, result_marital_rate: result_marital_rate }
      else
        render json: { result_heir_rate: 0, result_marital_rate: 0 }
      end
    end
  
    def result_business_succession
      tax_grace_amount
      result_heir_succession
      render json: { tax_grace_amount: @tax_grace_amount, result_heir_succession: step1_heir_succession }
    end
  
    private
  
    def permit_params
      params.permit(:total_heritage, :heir_special_stock_value, :other_heir_get_heritage, :marital_status,
                    :legal_heir, :children_count, :siblings_count, :marital_rate, :applied_condition, :commit)
    end
  end
  