class BoardController < ApplicationController
   def index
        @boards = Board.all
   end

   def show
      @board = Board.find_by(title: params[:id]) || Board.find(params[:id])
      unless @board
        redirect_to boards_path, alert: '掲示板が見つかりませんでした。'
      end
   end
   
 
end
