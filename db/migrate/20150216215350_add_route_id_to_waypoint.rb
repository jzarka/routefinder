class AddRouteIdToWaypoint < ActiveRecord::Migration
  def self.up
    add_column :waypoints, :route_id, :string
  end

  def self.down
    remove_column :waypoints, :route_id
  end
end
