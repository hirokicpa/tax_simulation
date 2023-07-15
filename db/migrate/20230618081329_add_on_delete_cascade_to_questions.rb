class AddOnDeleteCascadeToQuestions < ActiveRecord::Migration[6.1]
  def change
    change_column :questions, :user_id, :bigint
  end
end
