class Route < ActiveRecord::Base
    # {"LFPO"=>[48.723055555555554, 2.3794444444444447], "LFPG"=>[49.00972222222222, 2.5477777777777777]}
    has_many :waypoints
 
end
