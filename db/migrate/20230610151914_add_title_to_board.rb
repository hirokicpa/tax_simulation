class AddTitleToBoard < ActiveRecord::Migration[6.1]
  def change
    add_column :boards, :title, :string
  end
end
