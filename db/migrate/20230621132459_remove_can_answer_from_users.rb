class RemoveCanAnswerFromUsers < ActiveRecord::Migration[6.1]
  def change
    remove_column :users, :can_answer, :boolean
  end
end
