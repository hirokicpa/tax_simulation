class Simulations::FirstSecondSuccessionController < ApplicationController

  def index
  end

  def variables
		@maxTaxLimit = 16000
		@total_heritage = succession_params[:total_heritage].to_i
		@count_heir_children = succession_params[:count_heir_children].to_i
		@mate_own_heritage = succession_params[:mate_own_heritage].to_i

		@basic_reduction = 3000 + 600 * (@count_heir_children + 1 )
		@taxable_price = @total_heritage - @basic_reduction
		@marital_rates = [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
		@marital_percent = ["0 %", "10 %", "20 %", "30 %", "40 %", "50 %", "60 %", "70 %", "80 %", "90 %", "100 %"]
	end

# 1次相続：配偶者あり かつ (遺産総額1億6千万以下 または 配偶者法定相続以下)
	def first_succession_A(marital_rate)
		variables
# 相続人：配偶者＆子供
		@mate_houteisouzoku = (@taxable_price / 2).to_f
	    @children_houteisouzoku = ((@taxable_price / 2) / @count_heir_children).to_f
	    @result_mate = souzoku_tax(@mate_houteisouzoku).to_f
	    @result_children = souzoku_tax(@children_houteisouzoku).to_f
	    @first_succession_tax = (@result_mate).floor + (@result_children * @count_heir_children).floor
	    first_result = (@first_succession_tax * (1 - marital_rate)).floor
	    return first_result
	end

	# 1次相続：配偶者あり かつ 遺産総額1億6千万以上 かつ 配偶者法定相続以上
    def first_succession_B(marital_rate)
    	variables
    	mate_sum = (@taxable_price / 2).to_f
    	child_sum = ((@taxable_price / 2) /@count_heir_children).to_f
    	mate_tax = souzoku_tax(mate_sum).to_f
    	child_tax = souzoku_tax(child_sum).to_f
    	@total = (mate_tax + child_tax * @count_heir_children).to_f

    	if @total_heritage * 0.5 > @maxTaxLimit
			first_result = (@total * (1- marital_rate) + @total * marital_rate - @total * ((@total_heritage * 0.5).to_f / @total_heritage)).floor
    	elsif @total_heritage * 0.5 <= @maxTaxLimit
			if @total_heritage * marital_rate >= @maxTaxLimit
			first_result = (@total * (1- marital_rate) + @total * marital_rate - @total * (@maxTaxLimit.to_f / @total_heritage)).floor
			elsif @total_heritage * marital_rate < @maxTaxLimit
			first_result = (@total * (1- marital_rate) + @total * marital_rate - @total * ((@total_heritage * marital_rate).to_f / @total_heritage)).floor
			end
    	end

    end

	def souzoku_tax(sum)
		result = 0
		if sum <= 1000
	      result = (sum * 0.1).to_f
	    elsif sum > 1000 && sum <= 3000
	      result = ((sum * 0.15) - 50).to_f
	    elsif sum > 3000 && sum <= 5000
	      result = ((sum * 0.2) - 200).to_f
	    elsif sum > 5000 && sum <= 10000
	      result = ((sum * 0.3) - 700).to_f
	    elsif sum > 10000 && sum <= 20000
	      result = ((sum * 0.40) - 1700).to_f
	    elsif sum > 20000 && sum <= 30000
	      result = ((sum * 0.45) - 2700).to_f
	    elsif sum > 30000 && sum <= 60000
	      result = ((sum * 0.50) - 4200).to_f
	    elsif sum > 60000
	      result = ((sum * 0.55) - 7200).to_f
	    end
	    return result
	end



	def result_tax
		variables
	    @first_results = [] #@first_resultsを空の配列と定義した
	    @second_results = []
	    @total_results = []

	    if @total_heritage <= @maxTaxLimit
	      @marital_rates.each do |marital_rate|
		    # 1次相続結果
		    if @taxable_price >= 0
		      @first_results << first_succession_A(marital_rate) #first_succession_A(marital_rate)の計算結果を空の配列に入れている
		    else
		      @first_results << 0
		    end

		    # 2次相続結果
		    mate_sums = []
		    mate_sums << @total_heritage * marital_rate

		    heir_childrens = []
		    mate_sums.each do |mate_sum|
		      heir_children = mate_sum + @mate_own_heritage - (3000 + 600 * @count_heir_children)
		  
		      if heir_children >= 0
		        heir_childrens << heir_children
		      elsif heir_children < 0
		        heir_childrens << 0
		      end
		    end

		    heir_childrens.each do |heir_children|
		      child_sum = (heir_children / @count_heir_children).to_f
		      child_tax = souzoku_tax(child_sum).to_f
		      @second_results << (child_tax * @count_heir_children).floor
		    end
		  end

	    # ::::
        elsif @total_heritage > @maxTaxLimit
          @marital_rates.each do |marital_rate|

            if marital_rate <= 0.5 #１億6000万円以上かつ配偶者法定相続以下
            # 1次相続結果
              if @total_heritage >= 0
                 @first_results << first_succession_A(marital_rate)
              else
                @first_results << 0
              end
            # 2次相続結果
               mate_sums = []
               mate_sums << @total_heritage * marital_rate

               heir_childrens = []
               mate_sums.each do |mate_sum|
                 heir_children = mate_sum + @mate_own_heritage - (3000 + 600 * @count_heir_children)
                 if heir_children >= 0
                    heir_childrens << heir_children
                 elsif heir_children < 0
                    heir_childrens << 0
                 end
               end

               heir_childrens.each do |heir_children|
                 child_sum = (heir_children / @count_heir_children).to_f
                 child_tax = souzoku_tax(child_sum).to_f
                 @second_results << (child_tax * @count_heir_children).floor
               end
	         # ::::ƒ
	         # /////
	        elsif marital_rate > 0.5
	    	  #一次相続税
	    	  if @total_heritage >= 0
	    	  	 @first_results << first_succession_B(marital_rate)
                 else
                 @first_result << 0
                 end

                 #2次相続結果
                 mate_sum = (@taxable_price / 2).to_f
                 child_sum = ((@taxable_price - mate_sum) / @count_heir_children).to_f
                 mate_tax = souzoku_tax(mate_sum).to_f
                 child_tax = souzoku_tax(child_sum).to_f
                 @total = (mate_tax + child_tax * @count_heir_children).to_f

                 mate_sums = []
                 if @total_heritage * 0.5 >= @maxTaxLimit
                 mate_sums << @total_heritage * marital_rate - (@total * marital_rate - (@total * @total_heritage * 0.5 / @total_heritage)).floor

            elsif @total_heritage * 0.5 < @maxTaxLimit
              if @total_heritage * marital_rate >= @maxTaxLimit
                mate_sums << @total_heritage * marital_rate - (@total * marital_rate - (@total * @maxTaxLimit / @total_heritage)).floor
              elsif @total_heritage * marital_rate < @maxTaxLimit
                mate_sums << @total_heritage * marital_rate - (@total * marital_rate - (@total * @total_heritage * marital_rate / @total_heritage)).floor
              end
            end

            heir_childrens = []
            mate_sums.each do |mate_sum|
              heir_children = mate_sum + @mate_own_heritage - (3000 + 600 * @count_heir_children)
              
              if heir_children >= 0
              heir_childrens << heir_children
              elsif heir_children < 0
              heir_childrens << 0
              end

            end

            heir_childrens.each do |heir_children|
           	child_sum = (heir_children / @count_heir_children).to_f
            child_tax = souzoku_tax(child_sum).to_f
            @second_results << (child_tax * @count_heir_children).floor
            end

            # heir_childrens.each do |heir_children|
            #   child_sum = (heir_children / @count_heir_children).to_f
            #   child_tax = souzoku_tax(child_sum).to_f
            #   @second_results << (child_tax * @count_heir_children).floor
        end
      end
    end
  # /////
	    for i in 0..10 do
	    	# puts "<<<<<<<<<<<<<<<<<<<<<"
	    	# puts @first_results[i]
	    	# puts @second_results[i]
	      @total_results << @first_results[i] + @second_results[i]
	    end

	      @min_total_result = @total_results[0]
          @min_marital_percent = @marital_percent[0]
        for j in 1..10 do
          if @min_total_result > @total_results[j]
          @min_total_result = @total_results[j]
          @min_marital_percent = @marital_percent[j]
          end
        end

    @data = [{
      name: "1次相続税",
      data: [[@marital_percent[0], @first_results[0]], [@marital_percent[1], @first_results[1]], [@marital_percent[2], @first_results[2]], [@marital_percent[3], @first_results[3]], [@marital_percent[4], @first_results[4]], [@marital_percent[5], @first_results[5]], [@marital_percent[6], @first_results[6]], [@marital_percent[7], @first_results[7]], [@marital_percent[8], @first_results[8]], [@marital_percent[9], @first_results[9]], [@marital_percent[10], @first_results[10]]]
    },{
      name: "2次相続税",
      data: [[@marital_percent[0], @second_results[0]], [@marital_percent[1], @second_results[1]], [@marital_percent[2], @second_results[2]], [@marital_percent[3], @second_results[3]], [@marital_percent[4], @second_results[4]], [@marital_percent[5], @second_results[5]], [@marital_percent[6], @second_results[6]], [@marital_percent[7], @second_results[7]], [@marital_percent[8], @second_results[8]], [@marital_percent[9], @second_results[9]], [@marital_percent[10], @second_results[10]]]
    }]

		render :index
	   # end
    #   end
    end

    private
	def succession_params
		params.permit(:utf8, :commit, :total_heritage, :heir_children, :count_heir_children, :mate_own_heritage )
	end
end
