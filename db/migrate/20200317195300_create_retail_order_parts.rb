class CreateRetailOrderParts < ActiveRecord::Migration[5.1]
  def change
    create_table :retail_order_parts do |t|
      t.integer :retail_order_id
      t.string :partcode
      t.integer :qty
      t.string :partdesc
      t.string :uom
      t.boolean :new_part
      t.boolean :back_order

      t.timestamps
    end
  end
end
