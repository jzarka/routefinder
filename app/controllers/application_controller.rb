class ApplicationController < ActionController::Base
  protect_from_forgery
  include GeoKit::Geocoders
end
