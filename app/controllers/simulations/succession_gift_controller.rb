class Simulations::SuccessionGiftController < ApplicationController
	def index
	end

	def variables
		@total_heritage = succession_params[:total_heritage].to_i
		@count_heir_children = succession_params[:count_heir_children].to_i
		succession_params[:check_over_20] == "0" ? @count_over_20 = succession_params[:count_over_20].to_i : @count_over_20 = 0
		succession_params[:others] == "0" ? @count_others = succession_params[:count_others].to_i : @count_others = 0
		@one_person_gift = succession_params[:one_person_gift].to_i
		@years = succession_params[:years].to_i
		@gift_deduction = @one_person_gift - 110
		#贈与前：相続税　配偶者のみ
		@before_gift_heir_mate = @total_heritage - (3000 + 600)
		#贈与前：相続税　配偶者＆子供
		@before_gift_heir_mate_children = (@total_heritage - (3000 + 600 * (@count_heir_children + 1))).to_i 
		#贈与前：相続税　子供のみ
		@before_gift_heir_children = (@total_heritage - (3000 + 600 * @count_heir_children)).to_i
		#贈与後：相続税　配偶者のみ　贈与　配偶者のみ
		@after_gift_heir_mate_gift_mate = @total_heritage - @one_person_gift * @years * (1 + @count_over_20 + @count_others) - (3000 + 600)
		#贈与後：　相続税　配偶者と子供　贈与　配偶者のみ
		@after_gift_heir_mate_children_gift_mate = @total_heritage - @one_person_gift * @years * (1 + @count_over_20 + @count_others) - (3000 + 600 * (1 + @count_heir_children))
		#贈与後：　相続税　配偶者と子供　贈与　配偶者以外
		@after_gift_heir_mate_children_gift_children = @total_heritage - @one_person_gift * @years * (@count_over_20 + @count_others) - (3000 + 600 * (1 + @count_heir_children))
		#贈与後：　相続税　子供　贈与　配偶者以外
		@after_gift_heir_children_gift_children = @total_heritage - @one_person_gift * @years *(@count_over_20 + @count_others) -  (3000 + 600 * @count_heir_children)
	end

	def before_gift
		 variables
		if succession_params[:select_succession_mate] == "0" && succession_params[:select_succession_children] != "0" 
		  if @before_gift_heir_mate >= 0
		     mate_tax = succession_tax(@before_gift_heir_mate)
		     @result_before_gift = (mate_tax).floor
		  else
		 	 @result_before_gift = 0
		  end
		elsif succession_params[:select_succession_mate] == "0" && succession_params[:select_succession_children] == "0"
		  if @before_gift_heir_mate_children >= 0
			 mate_sum = (@before_gift_heir_mate_children / 2).to_f
			 child_sum = (@before_gift_heir_mate_children / 2 /@count_heir_children).to_f
			 mate_tax = succession_tax(mate_sum)
			 child_tax = succession_tax(child_sum)
			 @result_before_gift = (mate_tax + child_tax * @count_heir_children).floor
		  else
			 @result_before_gift = 0
		  end
		elsif succession_params[:select_succession_mate] != "0" && succession_params[:select_succession_children] == "0"
		  if @before_gift_heir_children >= 0
			 child_sum = (@before_gift_heir_children  / @count_heir_children).to_f
			 child_tax = succession_tax(child_sum)
			 @result_before_gift = (child_tax * @count_heir_children).floor
		  elsif 
			 @result_before_gift = 0
		  end	
		end
	end

	def gift_method
		variables
		   @gift_deduction >= 0
		   gift_deduction = (@gift_deduction).to_f
		 if succession_params[:check_over_20] == "0" && succession_params[:select_gift_mate] != "0" && succession_params[:others] !="0"
		   child_gift_tax = gift_special_tax(gift_deduction).to_f
		   @result_gift = (child_gift_tax * @years * @count_over_20).floor
		 elsif succession_params[:check_over_20] != "0" && succession_params[:select_gift_mate] == "0" && succession_params[:others] !="0"
		   mate_gift_tax = gift_general_tax(gift_deduction).to_f
		   @result_gift = (mate_gift_tax * @years).floor
		 elsif succession_params[:check_over_20] != "0" && succession_params[:select_gift_mate] != "0" && succession_params[:others] =="0"
		   other_gift_tax = gift_general_tax(gift_deduction).to_f
		   @result_gift = (other_gift_tax * @years * @count_others).floor
		 elsif succession_params[:check_over_20] == "0" && succession_params[:select_gift_mate] == "0" && succession_params[:others] == "0" 
		   child_gift_tax = gift_special_tax(gift_deduction).to_f
		   other_gift_tax = gift_general_tax(gift_deduction).to_f
		   mate_gift_tax = gift_general_tax(gift_deduction).to_f
		   @result_gift = ((child_gift_tax * @count_over_20 + other_gift_tax * @count_others + mate_gift_tax) * @years).floor
		 elsif succession_params[:check_over_20] == "0" && succession_params[:select_gift_mate] == "0" && succession_params[:others] != "0" 
		   child_gift_tax = gift_special_tax(gift_deduction).to_f
		   mate_gift_tax = gift_general_tax(gift_deduction).to_f
		   @result_gift = ((child_gift_tax * @count_over_20 + mate_gift_tax) * @years).floor
		 elsif succession_params[:check_over_20] == "0" && succession_params[:select_gift_mate] != "0" && succession_params[:others] == "0" 
		   child_gift_tax = gift_special_tax(gift_deduction).to_f
		   other_gift_tax = gift_general_tax(gift_deduction).to_f
		   @result_gift = ((child_gift_tax * @count_over_20 + other_gift_tax * @count_others) * @years).floor
		 elsif succession_params[:check_over_20] != "0" && succession_params[:select_gift_mate] == "0" && succession_params[:others] == "0" 
		   mate_gift_tax = gift_general_tax(gift_deduction).to_f
		   other_gift_tax = gift_general_tax(gift_deduction).to_f
		   @result_gift = ((mate_gift_tax + other_gift_tax * @count_others) * @years).floor        
		 end

	end

	def after_gift
		variables
		if succession_params[:select_succession_mate] == "0" && succession_params[:select_succession_children] != "0" && succession_params[:select_gift_mate] == "0"
			if @after_gift_heir_mate_gift_mate > 0
			     mate_tax = succession_tax(@after_gift_heir_mate_gift_mate).to_f
			     @result_after_gift = (mate_tax).floor
			else
		 	     @result_after_gift = 0
		    end
		elsif succession_params[:select_succession_mate] == "0" && succession_params[:select_succession_children] == "0" && succession_params[:select_gift_mate] == "0"
			if @after_gift_heir_mate_children_gift_mate > 0
			     mate_sum = (@after_gift_heir_mate_children_gift_mate / 2).to_f
			     mate_tax = succession_tax(mate_sum).to_f
			     child_sum = (@after_gift_heir_mate_children_gift_mate / 2 / @count_heir_children).to_f
			     child_tax = succession_tax(child_sum).to_f
			     @result_after_gift = (mate_tax + child_tax * @count_heir_children).floor
		    else
		         @result_after_gift = 0
		    end
		elsif succession_params[:select_succession_mate] == "0" && succession_params[:select_succession_children] == "0" && succession_params[:select_gift_mate] != "0"
			if @after_gift_heir_mate_children_gift_children > 0
				 mate_sum = (@after_gift_heir_mate_children_gift_children / 2).to_f
				 mate_tax = succession_tax(mate_sum).to_f
				 child_sum = (@after_gift_heir_mate_children_gift_children / 2 / @count_heir_children).to_f
				 child_tax = succession_tax(child_sum).to_f
				 @result_after_gift = (mate_tax + child_tax * @count_heir_children).floor
		    else
		         @result_after_gift = 0
		    end
		elsif succession_params[:select_succession_mate] != "0" && succession_params[:select_succession_children] == "0" && succession_params[:select_gift_mate] != "0"
			if @after_gift_heir_children_gift_children > 0
				 child_sum = (@after_gift_heir_children_gift_children / @count_heir_children).to_f
				 child_tax = succession_tax(child_sum).to_f
				 @result_after_gift = (child_tax * @count_heir_children).floor
		    else
		         @result_after_gift = 0
		    end

		end

	end

	def succession_tax(sum)
		result = 0
		if sum <= 1000
			result = (sum * 0.1).to_f
		elsif sum > 1000 && sum <=3000
			result = ((sum * 0.15) - 50).to_f
		elsif sum > 3000 && sum <= 5000
			result = ((sum * 0.2) - 200).to_f
		elsif sum > 5000 && sum <= 10000
			result = ((sum * 0.3) - 700).to_f
		elsif sum > 10000 && sum <= 20000
			result = ((sum * 0.4) - 1700).to_f
		elsif sum > 20000 && sum <= 30000
			result = ((sum * 0.45) - 2700).to_f
		elsif sum > 30000 && sum <= 60000
		    result = ((sum * 0.5) - 4200).to_f
		 elsif sum > 60000
		    result = ((sum * 0.55) - 7200).to_f
		 end
		 return result
	end

	def gift_special_tax(sum)
		result = 0
		if sum <= 200
			result = (sum *0.1).to_f
		elsif sum > 200 && sum <= 400
			result = ((sum * 0.15) -10).to_f
		elsif sum > 400 && sum <= 600
			result = ((sum * 0.2) - 30).to_f
		elsif sum > 600 && sum <= 1000
			result = ((sum * 0.3) - 90).to_f
		elsif sum > 1000 && sum <= 1500
		    result = ((sum * 0.4) - 190).to_f
		elsif sum > 1500 && sum<= 3000
		    result = ((sum * 0.45) - 265).to_f
		elsif sum > 3000 && sum <= 4500
			result = ((sum * 0.5) -415).to_f
		elsif sum > 4500
		    result = ((sum * 0.55) - 640).to_f
		end
		return result 
	end

	def gift_general_tax(sum)
		result = 0
		if sum <= 200
		    result = (sum * 0.1).to_f
	    elsif sum > 200 && sum <= 300
	        result = ((sum * 0.15) -10).to_f
	    elsif sum > 300 && sum <= 400
            result = ((sum *0.2) - 25).to_f
        elsif sum > 400 && sum<= 600
            result = ((sum * 0.3) - 65).to_f
        elsif sum > 600 && sum <= 1000
            result = ((sum * 0.40) - 125).to_f
        elsif sum > 1000 && sum <= 1500
            result = ((sum * 0.45) - 175).to_f
        elsif sum > 1500 && sum <= 3000
            result = ((sum * 0.50) - 250).to_f
        elsif sum > 3000
            result = ((sum * 0.55) - 400).to_f
        end
        return result
 	end



	def result_tax
		variables
		before_gift
		gift_method
		after_gift
		render :index
	end

	private
	def succession_params
		params.permit(:utf8,:commit,:total_heritage,:select_succession_mate,:select_succession_children,:count_heir_children,:select_gift_mate, :check_over_20, :count_over_20, :others, :count_others, :one_person_gift, :years)
	end
end