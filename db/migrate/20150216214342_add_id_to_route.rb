class AddIdToRoute < ActiveRecord::Migration
  def self.up
    add_column :routes, :id_adep_ades, :string
  end

  def self.down
    remove_column :routes, :id_adep_ades
  end
end
