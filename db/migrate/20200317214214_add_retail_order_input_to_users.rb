class AddRetailOrderInputToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :retail_order_input, :boolean
  end
end
