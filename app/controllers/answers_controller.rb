class AnswersController < ApplicationController
  def create
    @question = Question.find(params[:question_id])
    @answer = @question.answers.new(answer_params)
    @answer.user = current_user

    if @answer.save
      redirect_to board_question_path(@question.board, @question), notice: "回答を投稿しました。"
    else
      render "questions/show"
    end
  end

  private

  def answer_params
    params.require(:answer).permit(:content)
  end
end
