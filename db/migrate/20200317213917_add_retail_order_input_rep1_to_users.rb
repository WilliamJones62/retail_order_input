class AddRetailOrderInputRep1ToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :retail_order_input_rep1, :string
  end
end
