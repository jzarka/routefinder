load 'sample_routes.rb'

class RouteController < ApplicationController
  require 'nokogiri'
  require 'net/http'
  require 'ym4r'
  require 'json'
  include Ym4r::GoogleMaps
  include ::SampleRoutes

  def airports
    file = File.read('public/airports.json')
    airport_icao = []
    airport_num = 0
    data_hash = JSON.parse(file)
    airports_rows = data_hash['rows']
    airports_rows.each do |airport|
      airport_icao <<  {'label' => airport['icao'], 'name' => airport['name'], 'country' => airport['country']}
    end

    render :json => airport_icao

  end

  def find
  end

  def show
  end

  def get
    adep = params[:id][0..3]
    ades = params[:id][5..8]
    puts 'getting route ' + adep + ' to ' + ades
    route = getRouteFromAsalink(adep, ades)
#    render json: json_route(route).to_json
    render json: route.to_json(:include => :waypoints)
    # render json: sample_g_json().to_json
  end

  def getTestRoute
    puts 'finding route for airports: ' + 'EKCH' + ' to ' + 'ades ' + 'WSSS'
    adep = 'EKCH'
    ades = 'WSSS'
    route_id = adep + '_' + ades

    if !Route.exists?(id_adep_ades: route_id)

      route = Route.new(:id_adep_ades => adep + '_' + ades)
      route.save
      points = []
      points_hash = Hash.new

      # Test.html
      url = URI.parse('http://localhost:3000/test.html')
      req = Net::HTTP::Get.new(url.path)

      res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
      case res
      when Net::HTTPSuccess, Net::HTTPRedirection
        html_doc = Nokogiri::HTML(res.body)
        #      puts html_doc
        #      puts html_doc.xpath('//pre')
        html_doc.xpath('//pre').each do | pre |
          #        puts pre.class
          #        puts 'test test'
          #        puts pre.element_children
          pre.to_s.each_line {|s|
            if s.length > 4
              if !s.starts_with? "ID"
                if !s.starts_with? "</pre>"
                  line = s
                  #                puts 'line'
                  #                puts line
                  latlong = line[29..40] + ' ' + line[44..56]
                  point = []
                  line[29..40].gsub(/(\d+).(\d+)'(\d+).[0-9][0-9]/) do
                  lat = (line[29..30].to_f + $2.to_f/60 + $3.to_f/3600)
                  if line[28] == 83 # E/Z
                    lat = -lat
                  end
                  point << lat
                  line[43..56].gsub(/(\d+).(\d+)'(\d+).[0-9][0-9]/) do
                  long = ($1.to_f + $2.to_f/60 + $3.to_f/3600)
                  if line[43] == 87 # E/Z
                    long = -long
                  end
                  route.waypoints.create(:name => line, :latitude => lat, :longitude => long)
                  # wp = Waypoint.new(:name => line, :latitude => lat, :longitude => long)
                  point << long
                  #                point << line[0..10] + line[28..56]
                end
                #    points_hash.store(line, point)
                #    points << point
              end
            end
          end
          # puts 'points'
          #        puts points
          # puts points_hash.to_s
        end
      }
      puts
    end
  else
    res.error!
  end
  route.save
  route
else
  Route.where(id_adep_ades: route_id)
end
end

def getRouteFromAsalink(adep, ades)
  puts 'finding route for airports: ' + adep + ' to ' + 'ades' + ades
  route_id = adep + '_' + ades
  if !Route.exists?(id_adep_ades: route_id)
    route = Route.new(id_adep_ades: route_id)
    route.save
    points = []
    points_hash = Hash.new

    # real getting the route
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
        pre.to_s.each_line {|s|
          if s.length > 4
            if !s.starts_with? "ID"
              if !s.starts_with? "</pre>"
                line = s
                #                puts 'line'
                #                puts line
                latlong = line[29..40] + ' ' + line[44..56]
                point = []
                line[29..40].gsub(/(\d+).(\d+)'(\d+).[0-9][0-9]/) do
                lat = (line[29..30].to_f + $2.to_f/60 + $3.to_f/3600)
                if line[28] == 83 # E/Z
                  lat = -lat
                end
                point << lat
                line[43..56].gsub(/(\d+).(\d+)'(\d+).[0-9][0-9]/) do
                long = ($1.to_f + $2.to_f/60 + $3.to_f/3600)
                if line[43] == 87 # E/Z
                  long = -long
                end
                point << long
                #                point << line[0..10] + line[28..56]
                route.waypoints.create(:name => line, :latitude => lat, :longitude => long)
              end
              #                  points_hash.store(line, point)
              #                  points << point
            end
          end
        end
        #            puts 'points'
        #            puts points_hash.to_s
      end
    }
    puts
  end
else
  res.error!
end
else
  Route.where(id_adep_ades: route_id)
end
end

def display_route
  adep = params[:ADEP]
  ades = params[:ADES]
  puts 'finding route for airports: ' + adep + ' to ' + 'ades' + ades
  points = []
  points_hash = Hash.new
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
    #      puts html_doc
    #      puts html_doc.xpath('//pre')
    html_doc.xpath('//pre').each do | pre |
      #        puts pre.class
      #        puts 'test test'
      #        puts pre.element_children
      pre.to_s.each_line {|s|
        if s.length > 4
          if !s.starts_with? "ID"
            if !s.starts_with? "</pre>"
              line = s
              #                puts 'line'
              #                puts line
              latlong = line[29..40] + ' ' + line[44..56]
              point = []
              line[29..40].gsub(/(\d+).(\d+)'(\d+).[0-9][0-9]/) do
              lat = (line[29..30].to_f + $2.to_f/60 + $3.to_f/3600)
              if line[28] == 83 # E/Z
                lat = -lat
              end
              point << lat
              line[43..56].gsub(/(\d+).(\d+)'(\d+).[0-9][0-9]/) do
              long = ($1.to_f + $2.to_f/60 + $3.to_f/3600)
              if line[43] == 87 # E/Z
                long = -long
              end
              point << long
              #                point << line[0..10] + line[28..56]
            end
            points_hash.store(line, point)
            points << point
          end
        end
      end
      puts 'points'
      #        puts points
      puts points_hash.to_s
    end
  }
  puts
end
else
  res.error!
end
map(points)
end

def to_google_json(points)
  # {"LFPO"=>[48.723055555555554, 2.3794444444444447], "LFPG"=>[49.00972222222222, 2.5477777777777777]} 
  # google_json = Hash.new()
  #  google_json.store("type", "FeatureCollection")
  #  features = Hash.new()
  #  features.store("type", "Feature")
  #  features.store
  #  {
  #        "type": "Feature",
  #        "properties": {
  #          "letter": "G",
  #          "color": "blue",
  #          "rank": "7",
  #          "ascii": "71"
  #        },
  #  google_json.store("features", "FeatureCollection")
  googe_json = {
    "type"=> "FeatureCollection",
    "features"=> [
      {
        "type"=> "Feature",
        "properties"=> {
          "letter"=> "G",
          "color"=> "blue",
          "rank"=> "7",
          "ascii"=> "71"
          },
          "geometry"=> {
            "type"=> "Polygon",
            "coordinates"=> [
              [
                points.values
              ]
            ]
          }
        }
      ]
    }
  end
  def display_sample_route
    puts "display sample route !!"
    #  sample_route_hash = {"LFPO             0      0   N48°43'23.81\" E002°22'46.48\" PARIS ORLY\n"=>[48.723055555555554, 2.3794444444444447], "RANUX           71     82   N49°08'20.00\" E004°21'42.00\" RANUX\n"=>[49.138888888888886, 4.361666666666666], "MEDOX           68     31   N49°20'01.00\" E005°05'49.00\" MEDOX\n"=>[49.33361111111111, 5.0969444444444445], "VALEK           68     29   N49°30'52.00\" E005°46'52.00\" VALEK\n"=>[49.51444444444444, 5.781111111111111], "LIPNI           70      3   N49°31'48.00\" E005°50'45.00\" LIPNI\n"=>[49.53, 5.845833333333333], "LIMGO           70     18   N49°38'14.00\" E006°16'54.00\" LIMGO\n"=>[49.63722222222222, 6.281666666666666], "PITES           60     11   N49°43'43.00\" E006°31'10.00\" PITES\n"=>[49.728611111111114, 6.519444444444445], "OBIGA           53     30   N50°01'51.00\" E007°08'18.00\" OBIGA\n"=>[50.030833333333334, 7.138333333333334], "RUDUS           89     36   N50°02'51.32\" E008°04'41.77\" RUDUS\n"=>[50.0475, 8.078055555555554], "FFM     114.2   90     22   N50°03'13.47\" E008°38'13.53\" FRANKFURT MAIN\n"=>[50.05361111111111, 8.636944444444444], "BOMBI           90      6   N50°03'24.00\" E008°48'01.20\" BOMBI\n"=>[50.056666666666665, 8.800277777777778], "ESATI           90     15   N50°03'47.00\" E009°11'24.00\" ESATI\n"=>[50.06305555555555, 9.19], "LOHRE           90     11   N50°04'01.00\" E009°29'11.00\" LOHRE\n"=>[50.066944444444445, 9.486388888888888], "OSBIT           91     11   N50°04'12.00\" E009°46'59.00\" OSBIT\n"=>[50.07, 9.783055555555556], "RASPU           91     12   N50°04'22.00\" E010°05'55.00\" RASPU\n"=>[50.07277777777778, 10.098611111111111], "KOMIB           92      6   N50°04'24.00\" E010°14'34.00\" KOMIB\n"=>[50.07333333333334, 10.242777777777777], "SULUS           91     19   N50°04'31.00\" E010°43'44.00\" SULUS\n"=>[50.07527777777778, 10.72888888888889], "LONLI           92     19   N50°04'29.06\" E011°13'34.99\" LONLI\n"=>[50.07472222222223, 11.226111111111111], "KULOK           92     16   N50°04'22.09\" E011°37'50.00\" KULOK\n"=>[50.07277777777778, 11.630555555555556], "ABERU           93     18   N50°04'09.10\" E012°05'37.39\" ABERU\n"=>[50.06916666666667, 12.093611111111112], "OKG     115.7   94     12   N50°03'54.53\" E012°24'20.66\" CHEB\n"=>[50.065, 12.405555555555557], "DONAD           90     23   N50°04'50.93\" E013°00'00.00\" DONAD\n"=>[50.080555555555556, 13.0], "DOPOV           93      5   N50°04'50.93\" E013°07'30.40\" DOPOV\n"=>[50.080555555555556, 13.125], "BALTU           89      8   N50°05'22.06\" E013°19'35.48\" BALTU\n"=>[50.089444444444446, 13.32638888888889], "RAK     386     91     14   N50°05'49.41\" E013°41'26.58\" RAKOVNIK\n"=>[50.096944444444446, 13.690555555555555], "OKL     112.6   93     22   N50°05'44.80\" E014°15'55.81\" PRAHA\n"=>[50.095555555555556, 14.265277777777778], "LETNA           95      6   N50°05'31.29\" E014°25'19.84\" LETNA\n"=>[50.091944444444444, 14.421944444444444], "PEMUR           96     43   N50°03'16.81\" E015°32'17.65\" PEMUR\n"=>[50.05444444444444, 15.538055555555555], "DOBIL           97     15   N50°02'19.28\" E015°56'14.61\" DOBIL\n"=>[50.03861111111111, 15.937222222222223], "VAMBO           97     19   N50°01'01.47\" E016°25'48.10\" VAMBO\n"=>[50.01694444444444, 16.43], "SOPAV           98     63   N49°55'51.32\" E018°03'09.00\" SOPAV\n"=>[49.93083333333333, 18.052500000000002], "PADKA           93      9   N49°56'02.00\" E018°17'00.00\" PADKA\n"=>[49.93388888888889, 18.283333333333335], "SKAVI           93     62   N49°56'25.00\" E019°54'00.00\" SKAVI\n"=>[49.94027777777777, 19.9], "ADOKI           94     29   N49°56'09.00\" E020°38'45.00\" ADOKI\n"=>[49.93583333333333, 20.645833333333332], "LUXAR           95     20   N49°55'48.00\" E021°10'31.00\" LUXAR\n"=>[49.93, 21.17527777777778], "DIBED           96     73   N49°53'18.00\" E023°03'30.00\" DIBED\n"=>[49.888333333333335, 23.058333333333334], "NALAD          107    135   N49°23'18.00\" E026°27'06.00\" NALAD\n"=>[49.388333333333335, 26.451666666666664], "KOROP          110     56   N49°09'00.00\" E027°50'42.00\" KOROP\n"=>[49.15, 27.845], "NM      1060   111     41   N48°58'00.00\" E028°51'00.00\" NEMIRIV\n"=>[48.96666666666667, 28.85], "REPLI          112    168   N48°07'06.00\" E032°53'18.00\" REPLI\n"=>[48.11833333333333, 32.888333333333335], "DOTEL          120     30   N47°55'14.00\" E033°34'43.00\" DOTEL\n"=>[47.92055555555555, 33.578611111111115], "TOKMU          120     98   N47°14'48.00\" E035°47'24.00\" TOKMU\n"=>[47.24666666666667, 35.79], "OLGIN          124     76   N46°39'30.00\" E037°25'18.00\" OLGIN\n"=>[46.65833333333333, 37.42166666666667], "INSER          121     70   N46°10'54.00\" E038°57'36.00\" INSER\n"=>[46.181666666666665, 38.96], "UH      528    121     51   N45°50'00.00\" E040°05'00.00\" TIKHORETSK\n"=>[45.833333333333336, 40.083333333333336], "LEGNA          124     67   N45°19'18.00\" E041°30'24.00\" LEGNA\n"=>[45.32166666666667, 41.50666666666667], "TESMI          123     29   N45°06'30.00\" E042°06'48.00\" TESMI\n"=>[45.108333333333334, 42.11333333333334], "ALEGI          128     44   N44°43'30.00\" E043°00'00.00\" ALEGI\n"=>[44.725, 43.0], "BADKO          127     25   N44°30'42.00\" E043°30'30.00\" BADKO\n"=>[44.51166666666666, 43.50833333333333], "RISKA          127     53   N44°04'00.00\" E044°35'00.00\" RISKA\n"=>[44.06666666666667, 44.583333333333336], "GOTIK          125     72   N43°29'24.00\" E046°02'30.00\" GOTIK\n"=>[43.49, 46.041666666666664], "MKL     113.2  126     81   N42°49'16.00\" E047°38'44.00\" MAKHACHKALA\n"=>[42.821111111111115, 47.64555555555555], "BISNA          122     81   N42°14'00.00\" E049°17'00.00\" BISNA\n"=>[42.233333333333334, 49.28333333333333], "MARAL          124    112   N41°21'36.00\" E051°30'00.00\" MARAL\n"=>[41.36, 51.5], "TABAB          124     57   N40°54'12.00\" E052°36'30.00\" TABAB\n"=>[40.90333333333333, 52.608333333333334], "MAHYM          125    129   N39°49'54.00\" E055°02'54.00\" MAHYM\n"=>[39.83166666666667, 55.04833333333333], "BIBIM          125     16   N39°41'42.00\" E055°21'30.00\" BIBIM\n"=>[39.69499999999999, 55.358333333333334], "ABEKO          111     26   N39°34'30.00\" E055°53'54.00\" ABEKO\n"=>[39.575, 55.89833333333333], "KEKAL          111     44   N39°22'06.00\" E056°48'30.00\" KEKAL\n"=>[39.36833333333333, 56.80833333333333], "TABIP          112     74   N39°00'00.00\" E058°20'00.00\" TABIP\n"=>[39.0, 58.333333333333336], "BODBA          121     15   N38°53'12.00\" E058°37'42.00\" BODBA\n"=>[38.88666666666666, 58.62833333333333], "ABDAN          121     39   N38°35'42.00\" E059°22'00.00\" ABDAN\n"=>[38.595, 59.36666666666667], "ABDUR          111    117   N38°00'48.00\" E061°43'36.00\" ABDUR\n"=>[38.013333333333335, 61.72666666666667], "EMGIL          113     30   N37°51'30.00\" E062°19'36.00\" EMGIL\n"=>[37.858333333333334, 62.32666666666667], "UTOMA          130     89   N36°59'18.00\" E063°50'12.00\" UTOMA\n"=>[36.98833333333334, 63.836666666666666], "LEMOD          160     54   N36°10'00.00\" E064°17'30.00\" LEMOD\n"=>[36.166666666666664, 64.29166666666667], "VUVEN          130    162   N34°32'30.00\" E066°55'30.00\" VUVEN\n"=>[34.541666666666664, 66.92500000000001], "NEVIV          131     54   N33°58'48.00\" E067°47'00.00\" NEVIV\n"=>[33.980000000000004, 67.78333333333333], "PATOX          132     41   N33°32'54.00\" E068°25'12.00\" PATOX\n"=>[33.54833333333333, 68.42], "MESRA          133     25   N33°16'39.46\" E068°47'56.11\" MESRA\n"=>[33.277499999999996, 68.79888888888888], "PAVLO          130     40   N32°51'58.98\" E069°25'58.98\" PAVLO\n"=>[32.86611111111111, 69.43277777777779], "PARAK          130     48   N32°22'12.00\" E070°11'00.00\" PARAK\n"=>[32.37, 70.18333333333334], "DI      113.1  129     45   N31°54'45.50\" E070°53'08.42\" DERA ISMAIL KHAN\n"=>[31.912499999999998, 70.88555555555556], "JHANG          120     82   N31°16'00.00\" E072°18'00.00\" JHANG\n"=>[31.266666666666666, 72.3], "NIKET          127     61   N30°40'55.00\" E073°15'30.00\" NIKET\n"=>[30.681944444444447, 73.25833333333334], "GUGAL          127     45   N30°14'29.50\" E073°57'57.00\" GUGAL\n"=>[30.24138888888889, 73.96583333333334], "BUTOP          127     93   N29°19'44.80\" E075°23'56.30\" BUTOP\n"=>[29.328888888888887, 75.39888888888889], "IGONA          128    328   N25°58'00.30\" E080°15'30.10\" IGONA\n"=>[25.966666666666665, 80.25833333333334], "DOMET          128     81   N25°08'30.40\" E081°26'30.20\" DOMET\n"=>[25.141666666666666, 81.44166666666668], "LAPAN          127    138   N23°43'55.00\" E083°26'07.60\" LAPAN\n"=>[23.731944444444444, 83.43527777777778], "AGROM          133    106   N22°31'45.30\" E084°50'00.40\" AGROM\n"=>[22.529166666666665, 84.83333333333333], "KAKID          132    166   N20°38'33.10\" E086°59'51.20\" KAKID\n"=>[20.6425, 86.9975], "BUBKO          132    129   N19°11'03.70\" E088°39'50.50\" BUBKO\n"=>[19.184166666666666, 88.66388888888889], "MEPEL          133    269   N16°02'00.00\" E092°00'00.00\" MEPEL\n"=>[16.033333333333335, 92.0], "SADUS          134     51   N15°25'41.00\" E092°37'52.00\" SADUS\n"=>[15.428055555555554, 92.63111111111111], "LALAT          132    224   N12°50'49.00\" E095°25'08.00\" LALAT\n"=>[12.846944444444444, 95.41888888888889], "OBMOG          134     80   N11°54'07.00\" E096°23'31.00\" OBMOG\n"=>[11.901944444444444, 96.39194444444445], "IKULA          153    127   N10°00'06.90\" E097°21'14.00\" IKULA\n"=>[10.001666666666667, 97.35388888888889], "PUT     116.9  153    127   N08°06'54.83\" E098°18'22.69\" PHUKET\n"=>[8.115, 98.30611111111111], "DALAN          140    127   N06°28'08.00\" E099°39'20.00\" DALAN\n"=>[6.468888888888889, 99.65555555555557], "VPL     114.1  141      9   N06°21'19.40\" E099°44'50.60\" LANGKAWI\n"=>[6.355277777777777, 99.74722222222222], "ANDOK          143     25   N06°01'20.00\" E100°00'00.00\" ANDOK\n"=>[6.022222222222222, 100.0], "VILAT          143     10   N05°53'28.00\" E100°05'57.00\" VILAT\n"=>[5.891111111111111, 100.09916666666666], "VIH     117.3  143     99   N04°34'22.90\" E101°05'37.00\" IPOH\n"=>[4.572777777777778, 101.0936111111111], "ANSOM          138     40   N04°04'24.00\" E101°32'19.00\" ANSOM\n"=>[4.073333333333333, 101.53861111111111], "LATUK          138     92   N02°55'16.00\" E102°33'46.00\" LATUK\n"=>[2.9211111111111108, 102.56277777777777], "DAMAL          138     47   N02°19'55.00\" E103°05'12.00\" DAMAL\n"=>[2.3319444444444444, 103.08666666666666], "VJR     112.7  139     48   N01°43'48.00\" E103°37'18.00\" JOHOR BAHRU\n"=>[1.7300000000000002, 103.62166666666666], "WSSS           135     31   N01°21'33.16\" E103°59'21.60\" SINGAPORE / SINGAPORE CHANGI IWS\n"=>[1.3591666666666669, 103.98916666666666]}
    sample_route_hash = {"LFPO"=>[-34.397, 150.644], "RANUX"=>[-34.397 +1, 150.644 +1]}
    puts 'storing to retrieve on front end'
    #sample_route_hash_google = to_google_json(sample_route_hash)
    #sample_route_hash_google = to_google_json(sample_google_json())


    @sample_route_hash = sample_google_json().to_json
    #@sample_route_hash =  sample_route_hash_google.to_json
  end
  def display_sample_route_data
#    render json: sample_google_json().to_json
    render json: sample_g_json().to_json
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
