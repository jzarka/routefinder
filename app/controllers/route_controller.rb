class RouteController < ApplicationController
  require 'nokogiri'
  require 'net/http'
  require 'ym4r'
  include Ym4r::GoogleMaps
  
  def find_route
  end
  
  def display_route
    puts 'exectuting this'
    adep = params[:ADEP]
    ades = params[:ADES]
    points = []
    url = URI.parse('http://rfinder.asalink.net/free/autoroute_rtx.php')
    req = Net::HTTP::Post.new(url.path)
    req.set_form_data('id1'=> adep,
                      'ic1' =>'',
                      'id2'=> ades,
                      'ic2'=> '',
                      'minalt'=>'FL330',
                      'maxalt'=>'FL330',
                      'lvl'=> 'B',
                      'dbid'=>'1012',
                      'usesid'=>'Y',
                      'usestar'=>'Y',
                      'rnav'=>'Y', 'nats'=>'',
                      'k'=>'653068009')

    res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
    case res
      when Net::HTTPSuccess, Net::HTTPRedirection
        puts 'request ok'
        html_doc = Nokogiri::HTML(res.body)
        html_doc.xpath('//pre').each do | pre | 
        pre.content.each {|s|
          if !s.starts_with? "ID"
            line = s
            puts line
            latlong = line[29..40] + ' ' + line[44..56]
            point = []
            line[29..40].gsub(/(\d+).(\d+)'(\d+).[0-9][0-9]/) do
            lat = ($1.to_f + $2.to_f/60 + $3.to_f/3600)
            point << lat
          end
          line[44..56].gsub(/(\d+).(\d+)'(\d+).[0-9][0-9]/) do
            long = ($1.to_f + $2.to_f/60 + $3.to_f/3600)
            puts line[43]
            if line[43] == 87
              long = -long
              puts long
            end
            point << long
            point << line[0..10] + line[28..56]
          end
          points << point
        end
        }
        puts
      end
    else
         res.error!
    end
    map(points)
  end
  private
    def map (points)
      @map = GMap.new("map_div")
    	@map.control_init(:large_map => true,:map_type => true)
    	previousPoint = nil
      points.each do |latlong|
        point = GLatLng.new([latlong[0],latlong[1]])
        @map.center_zoom_init(point, 2)
        @map.overlay_init GMarker.new(point, :info_window => latlong[2])
        if previousPoint != nil
          poly = GPolyline.new([previousPoint,point],"#ff0000",3,1.0)

          # @map.overlay_init GPolyline.new([[12.4,65.6],[4.5,61.2]],"#ff0000",3,1.0)
          @map.overlay_init GPolyline.new([[point.lat,point.lng],[previousPoint.lat,previousPoint.lng]],"#ff0000",3,1.0)
        end
        previousPoint = GLatLng.new([point.lat, point.lng])
      end
      @map
    end
end
