class AnswersController < ApplicationController
  before_action :set_question
  before_action :set_answer, only: [:edit, :update, :destroy]
  before_action :authenticate_user!

  def new
    @board = @question.board
    @answer = @question.answers.build
  end

  def create
    @answer = @question.answers.new(answer_params)
    @answer.user = current_user

    if @answer.save
      redirect_to board_question_path(@question.board, @question), notice: "回答を投稿しました。"
    else
      @board = @question.board
      render :new
    end
  end

  def edit
    @board = @question.board
  end

  def update
    if @answer.update(answer_params)
      redirect_to board_question_path(@question.board, @question), notice: "回答を更新しました。"
    else
      @board = @question.board
      render :edit
    end
  end

  def destroy
    @answer.destroy
    redirect_to board_question_path(@question.board, @question), notice: "回答を削除しました。"
  end

  private

  def set_question
    @question = Question.find(params[:question_id])
  end

  def set_answer
    @answer = @question.answers.find(params[:id])
  end

  def answer_params
    params.require(:answer).permit(:content)
  end
end
