class BoardController < ApplicationController
   def index
        @board = Board.all
   end

   def show
      @board = Board.find(params[:id])
   end
   
 
end
