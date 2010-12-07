class RoutesDownloader < ActionController::Base
  require 'nokogiri'
  require 'net/http'
  require 'yaml'


  def download_routes
    #
    airports = self.download_route('EKCH', 'EKBI')
  end

  def download_route(adep, ades)
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
          html_doc = Nokogiri::HTML(res.body)
          html_doc.xpath('//pre').each do | pre | 
          pre.content.each {|s|
            if !s.starts_with? "ID"
              line = s
              latlong = line[29..40] + ' ' + line[44..56]
              point = {}
              lat = self.convert_lat(line[28..40])
              point['lat'] = lat
              long = self.convert_long(line[43..56])
              point['long'] = long
              point['name'] = line[0..10]
              point['latlong'] = line[28..56]
              
              points << point
            end
          }
          puts
        end
      else
           res.error!
      end
      points
    end

  def convert_lat(latitude_str)
    latitude_str[1..12].gsub(/(\d+).(\d+)'(\d+).[0-9][0-9]/) do
      lat = (latitude_str[1..2].to_f + $2.to_f/60 + $3.to_f/3600)
      if latitude_str[0] == 83 # E/Z
        lat = -lat
      end
      lat
    end
  end

  def convert_long(longitude_str)
    longitude_str[1..13].gsub(/(\d+).(\d+)'(\d+).[0-9][0-9]/) do
      long = ($1.to_f + $2.to_f/60 + $3.to_f/3600)
      if longitude_str[0] == 87 # N/S
      long = -long
      end
      long
    end
  end

end