class QuestionsController < ApplicationController
  # before_action :question_params, only: [:show, :edit, :update, :destroy]
  before_action :set_question, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!

    def new
      @board = Board.find(params[:board_id])
      @question = Question.new
    end

    
    def show
       @board = Board.find(params[:board_id])
      set_question
    end

    def create
      @board = Board.find(params[:board_id])
      @question = @board.questions.new(question_params)
        if @question.save
          redirect_to @board, flash: {notice: "質問を投稿しました。"}
        else
          render :new
        end
    end
     
     
   
    private

    def set_question
     @question = Question.find(params[:id])
    end
    
    
    def question_params
     params.require(:question).permit(:title, :content).merge(user_id: current_user.id)
    end
end
