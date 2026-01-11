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
        # 配偶者の遺産取得割合の計算
        # 配偶者以外の相続人が子供1人の場合に限り、自動的に100%から後継者の遺産取得割合を控除
        if @marital_status == "0" && @legal_heir == "0" && @children_count == "1"
          # 自動計算を強制
          @marital_rate_show = (100 - @result_heir_rate_show).round(2)
          @marital_rate_disabled = true
        else
          # それ以外の場合は、入力値がある場合はそのまま使用、ない場合は自動計算
          if params[:marital_rate].present? && params[:marital_rate].to_f > 0
            @marital_rate_show = params[:marital_rate].to_f.round(2)
          else
            @marital_rate_show = (100 - @result_heir_rate_show).round(2)
          end
          @marital_rate_disabled = false
        end
      else
        @result_heir_rate_show = 0
        @marital_rate_show = params[:marital_rate] || ""
        @marital_rate_disabled = true
      end
      
      # JSON形式でリクエストされた場合の処理
      is_json_request = request.format.json? || request.headers['Accept']&.include?('application/json')
      
      Rails.logger.info "=== 計算開始 ==="
      Rails.logger.info "is_json_request: #{is_json_request}"
      Rails.logger.info "params[:commit]: #{params[:commit]}"
      Rails.logger.info "params: #{params.inspect}"
      
      # 計算実行（パラメータが存在する場合、またはJSONリクエストの場合）
      if params[:commit].present? || is_json_request
        Rails.logger.info "計算実行条件を満たしています"
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
        # 後継者の遺産取得割合が100%を超える場合のチェック
        if params[:total_heritage].present? && params[:total_heritage].to_f > 0
          total_heritage = params[:total_heritage].to_s.gsub(',', '').to_f
          heir_special_stock_value = (params[:heir_special_stock_value] || 0).to_s.gsub(',', '').to_f
          other_heir_get_heritage = (params[:other_heir_get_heritage] || 0).to_s.gsub(',', '').to_f
          
          # ②が遺産総額を超える場合
          if heir_special_stock_value > total_heritage
            @errors << "②特例適応対象株式の評価額は、①現在の遺産総額を超えることはできません。"
          end
          
          # ④が遺産総額を超える場合
          if other_heir_get_heritage > total_heritage
            @errors << "④後継者が取得するその他の財産は、①現在の遺産総額を超えることはできません。"
          end
          
          # ②+④の合計が遺産総額を超える場合
          if (heir_special_stock_value + other_heir_get_heritage) > total_heritage
            @errors << "②特例適応対象株式の評価額と④後継者が取得するその他の財産の合計は、①現在の遺産総額を超えることはできません。"
          end
          
          # 後継者の遺産取得割合が100%を超える場合
          heir_rate = ((heir_special_stock_value + other_heir_get_heritage) / total_heritage * 100).round(2)
          if heir_rate > 100
            @errors << "後継者の遺産取得割合が100%を超えることはできません。"
          end
        end
        # 配偶者の遺産取得割合のバリデーション
        # 配偶者以外の相続人が子供1人の場合は自動計算されるため、入力チェックをスキップ
        if @marital_status == "0" && !(@legal_heir == "0" && @children_count == "1")
          if params[:marital_rate].blank?
            @errors << "配偶者の遺産取得割合を入力してください。"
          elsif params[:marital_rate].present?
            marital_rate = params[:marital_rate].to_f
            # 後継者の遺産取得割合を計算
            if params[:total_heritage].present? && params[:total_heritage].to_f > 0
              total_heritage = params[:total_heritage].to_s.gsub(',', '').to_f
              heir_special_stock_value = (params[:heir_special_stock_value] || 0).to_s.gsub(',', '').to_f
              other_heir_get_heritage = (params[:other_heir_get_heritage] || 0).to_s.gsub(',', '').to_f
              heir_rate = ((heir_special_stock_value + other_heir_get_heritage) / total_heritage * 100).round(2)
              # 後継者の遺産取得割合 + 配偶者の遺産取得割合が100%を超える場合
              if (heir_rate + marital_rate) > 100
                @errors << "配偶者の遺産取得割合は、後継者の遺産取得割合と合わせて100%を超えることはできません。"
              end
            end
          end
        end
        if @legal_heir == "0" && (@children_count.blank? || @children_count.to_i == 0)
          # 子供が0人で兄弟姉妹の人数が選択されている場合はエラーを表示しない
          unless @siblings_count.present? && @siblings_count.to_i > 0
            @errors << "子供の人数を選択してください。"
          end
        end
        if @legal_heir == "2" && (@siblings_count.blank? || @siblings_count.to_i == 0)
          @errors << "兄弟姉妹の人数を選択してください。"
        end
        
        # エラーがなければ計算実行
        if @errors.empty?
          Rails.logger.info "エラーなし、計算を開始します"
          begin
            Rails.logger.info "variables を実行します"
            variables
            Rails.logger.info "variables 完了"
            
            Rails.logger.info "step1_result_tax を実行します"
            @result_succession = step1_result_tax
            Rails.logger.info "step1_result_tax 完了: #{@result_succession}"
            
            Rails.logger.info "step1_heir_succession を実行します"
            @result_heir_succession = step1_heir_succession
            Rails.logger.info "step1_heir_succession 完了: #{@result_heir_succession}"
            
            Rails.logger.info "tax_grace_amount を実行します"
            tax_grace_amount
            @result_tax_grace_amount = @tax_grace_amount
            Rails.logger.info "tax_grace_amount 完了: #{@result_tax_grace_amount}"
          rescue => e
            Rails.logger.error "計算エラー: #{e.class}: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            @errors << "計算中にエラーが発生しました: #{e.message}"
          end
        else
          Rails.logger.info "エラーがあります: #{@errors.inspect}"
        end
      else
        Rails.logger.info "計算実行条件を満たしていません"
      end
      
      # JSON形式でリクエストされた場合はJSONで返す
      if is_json_request
        Rails.logger.info "JSONレスポンスを返します"
        Rails.logger.info "@errors.empty?: #{@errors.empty?}"
        Rails.logger.info "@result_succession.present?: #{@result_succession.present?}"
        Rails.logger.info "@result_succession: #{@result_succession.inspect}"
        
        if @errors.empty? && @result_succession.present?
          Rails.logger.info "成功レスポンスを返します"
          render json: {
            success: true,
            result_succession: @result_succession.to_i,
            result_heir_succession: @result_heir_succession.to_i,
            result_tax_grace_amount: @result_tax_grace_amount.to_i,
            result_heir_rate_show: @result_heir_rate_show
          }
        else
          Rails.logger.info "エラーレスポンスを返します"
          render json: {
            success: false,
            errors: @errors.presence || ["計算に失敗しました。入力値を確認してください。"]
          }, status: :unprocessable_entity
        end
      else
        render 'simulations/business_succession/index'
      end
      
      Rails.logger.info "=== 計算終了 ==="
    end
  
    def variables
      @max_tax_limit = 16000
      p = permit_params || {}
      @total_heritage = (p[:total_heritage] || params[:total_heritage] || 0).to_s.gsub(',', '').to_f
      @heir_special_stock_value = (p[:heir_special_stock_value] || params[:heir_special_stock_value] || 0).to_s.gsub(',', '').to_f
      @other_heir_get_heritage = (p[:other_heir_get_heritage] || params[:other_heir_get_heritage] || 0).to_s.gsub(',', '').to_f
      @legal_heir     = p[:legal_heir] || params[:legal_heir] || "0"
      @marital_status = p[:marital_status] || params[:marital_status] || "0"
      @children_count = (p[:children_count] || params[:children_count] || "0").to_i
      @siblings_count = (p[:siblings_count] || params[:siblings_count] || "0").to_i
      @marital_rate   = ((p[:marital_rate] || params[:marital_rate] || 0).to_f / 100).to_d
  
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
      Rails.logger.info "step1_method_A 開始"
      Rails.logger.info "@legal_heir: #{@legal_heir}"
      Rails.logger.info "@children_count: #{@children_count}"
      Rails.logger.info "@siblings_count: #{@siblings_count}"
      case @legal_heir
      when "0" # 配偶者＆子
        # 子供が0人で兄弟姉妹が選択されている場合は兄弟姉妹の計算を行う
        if @children_count == 0 && @siblings_count > 0
          Rails.logger.info "子供が0人で兄弟姉妹が選択されている場合の計算"
          mate_sum     = @heir_mate_siblings_step1 * 3 / 4
          sibling_sum  = (@heir_mate_siblings_step1 - mate_sum) / @siblings_count
          result = (succession_tax(mate_sum) + succession_tax(sibling_sum) * @siblings_count) * 1.2
          Rails.logger.info "step1_method_A 完了: #{result}"
          return result
        end
        if @children_count == 0
          Rails.logger.info "子供が0人のため0を返します"
          return 0
        end
        Rails.logger.info "配偶者＆子の計算"
        mate_sum  = @heir_mate_children_step1 / 2
        child_sum = (@heir_mate_children_step1 - mate_sum) / @children_count
        result = succession_tax(mate_sum) + succession_tax(child_sum) * @children_count
        Rails.logger.info "step1_method_A 完了: #{result}"
        result
      when "2" # 配偶者＆兄弟姉妹
        Rails.logger.info "配偶者＆兄弟姉妹の計算"
        return 0 if @siblings_count == 0
        mate_sum     = @heir_mate_siblings_step1 * 3 / 4
        sibling_sum  = (@heir_mate_siblings_step1 - mate_sum) / @siblings_count
        result = (succession_tax(mate_sum) + succession_tax(sibling_sum) * @siblings_count) * 1.2
        Rails.logger.info "step1_method_A 完了: #{result}"
        result
      else
        Rails.logger.info "step1_method_A: 該当するケースがありません"
        0
      end
    end
  
    def step1_method_B
      case @legal_heir
      when "0" # 子のみ
        # 子供が0人で兄弟姉妹が選択されている場合は兄弟姉妹の計算を行う
        if @children_count == 0 && @siblings_count > 0
          sibling_sum = @heir_siblings_step1 / @siblings_count
          return succession_tax(sibling_sum) * @siblings_count * 1.2
        end
        return 0 if @children_count == 0
        child_sum = @heir_children_step1 / @children_count
        succession_tax(child_sum) * @children_count
      when "2" # 兄弟姉妹のみ
        return 0 if @siblings_count == 0
        sibling_sum = @heir_siblings_step1 / @siblings_count
        succession_tax(sibling_sum) * @siblings_count * 1.2
      else
        0
      end
    end
  
    def step2_method_A
      case @legal_heir
      when "0" # 配偶者＆子
        # 子供が0人で兄弟姉妹が選択されている場合は兄弟姉妹の計算を行う
        if @children_count == 0 && @siblings_count > 0
          mate_sum     = @heir_mate_siblings_step2 * 3 / 4
          sibling_sum  = (@heir_mate_siblings_step2 - mate_sum) / @siblings_count
          return (succession_tax(mate_sum) + succession_tax(sibling_sum) * @siblings_count) * 1.2
        end
        return 0 if @children_count == 0
        mate_sum  = @heir_mate_children_step2 / 2
        child_sum = (@heir_mate_children_step2 - mate_sum) / @children_count
        succession_tax(mate_sum) + succession_tax(child_sum) * @children_count
      when "2" # 配偶者＆兄弟姉妹
        return 0 if @siblings_count == 0
        mate_sum     = @heir_mate_siblings_step2 * 3 / 4
        sibling_sum  = (@heir_mate_siblings_step2 - mate_sum) / @siblings_count
        (succession_tax(mate_sum) + succession_tax(sibling_sum) * @siblings_count) * 1.2
      else
        0
      end
    end
  
    def step2_method_B
      case @legal_heir
      when "0" # 子のみ
        # 子供が0人で兄弟姉妹が選択されている場合は兄弟姉妹の計算を行う
        if @children_count == 0 && @siblings_count > 0
          sibling_sum = @heir_siblings_step2 / @siblings_count
          return succession_tax(sibling_sum) * @siblings_count * 1.2
        end
        return 0 if @children_count == 0
        child_sum = @heir_children_step2 / @children_count
        succession_tax(child_sum) * @children_count
      when "2" # 兄弟姉妹のみ
        return 0 if @siblings_count == 0
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
      Rails.logger.info "step1_result_tax 開始"
      Rails.logger.info "@marital_status: #{@marital_status}"
      Rails.logger.info "@heir_mate_children_step1: #{@heir_mate_children_step1}"
      Rails.logger.info "@heir_mate_siblings_step1: #{@heir_mate_siblings_step1}"
      Rails.logger.info "@heir_children_step1: #{@heir_children_step1}"
      Rails.logger.info "@heir_siblings_step1: #{@heir_siblings_step1}"
      
      calc = lambda {
        if @marital_status == "0"
          Rails.logger.info "step1_method_A を呼び出します"
          result = step1_method_A
          Rails.logger.info "step1_method_A 完了: #{result}"
          result
        else
          Rails.logger.info "step1_method_B を呼び出します"
          result = step1_method_B
          Rails.logger.info "step1_method_B 完了: #{result}"
          result
        end
      }
  
      if @marital_status == "0"
        if @heir_mate_children_step1 < 0 || @heir_mate_siblings_step1 < 0
          Rails.logger.info "step1_result_tax: 負の値のため0を返します"
          return 0
        end
        result = calc.call
        Rails.logger.info "step1_result_tax 完了: #{result}"
        result
      else
        if @heir_children_step1 < 0 || @heir_siblings_step1 < 0
          Rails.logger.info "step1_result_tax: 負の値のため0を返します"
          return 0
        end
        result = calc.call
        Rails.logger.info "step1_result_tax 完了: #{result}"
        result
      end
    end
  
    def step2_result_tax
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
      Rails.logger.info "step1_heir_succession 開始"
      Rails.logger.info "@total_heritage: #{@total_heritage}"
      Rails.logger.info "@heir_special_stock_value: #{@heir_special_stock_value}"
      Rails.logger.info "@other_heir_get_heritage: #{@other_heir_get_heritage}"
      
      result_tax = step1_result_tax
      Rails.logger.info "step1_result_tax の結果: #{result_tax}"
      
      if @total_heritage == 0 || @total_heritage.nil?
        Rails.logger.info "step1_heir_succession: total_heritageが0またはnilのため0を返します"
        return 0
      end
      
      # NaNや無限大のチェック（Floatの場合のみ）
      if result_tax.is_a?(Float) && (result_tax.nan? || result_tax.infinite?)
        return 0
      end
      result = (result_tax * (@heir_special_stock_value + @other_heir_get_heritage) / @total_heritage).round(3).floor
      # 結果がFloatの場合のみNaN/無限大チェック
      if result.is_a?(Float) && (result.nan? || result.infinite?)
        return 0
      end
      result
    end
  
    def step2_heir_succession
      result_tax = step2_result_tax
      denominator = @total_heritage - @other_heir_get_heritage
      return 0 if denominator == 0 || denominator.nil?
      # NaNや無限大のチェック（Floatの場合のみ）
      if result_tax.is_a?(Float) && (result_tax.nan? || result_tax.infinite?)
        return 0
      end
      result = (result_tax * @heir_special_stock_value / denominator).round(3).floor
      # 結果がFloatの場合のみNaN/無限大チェック
      if result.is_a?(Float) && (result.nan? || result.infinite?)
        return 0
      end
      result
    end
  
    def tax_grace_amount
      Rails.logger.info "tax_grace_amount 開始"
      Rails.logger.info "step1_heir_succession を呼び出します"
      step1_result = step1_heir_succession
      Rails.logger.info "step1_heir_succession 完了: #{step1_result}"
      
      Rails.logger.info "step2_heir_succession を呼び出します"
      step2_result = step2_heir_succession
      Rails.logger.info "step2_heir_succession 完了: #{step2_result}"
      
      if step1_result <= step2_result
        @tax_grace_amount = step1_result
        Rails.logger.info "tax_grace_amount: step1を採用: #{@tax_grace_amount}"
      else
        @tax_grace_amount = step2_result
        Rails.logger.info "tax_grace_amount: step2を採用: #{@tax_grace_amount}"
      end
      Rails.logger.info "tax_grace_amount 完了: #{@tax_grace_amount}"
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
      variables
      tax_grace_amount
      render json: { tax_grace_amount: @tax_grace_amount, result_heir_succession: step1_heir_succession }
    end
  
    private
  
    def permit_params
      params.permit(:total_heritage, :heir_special_stock_value, :other_heir_get_heritage, :marital_status,
                    :legal_heir, :children_count, :siblings_count, :marital_rate, :applied_condition, :commit)
    end
  end
  