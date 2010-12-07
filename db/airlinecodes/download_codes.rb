class IcaoAirportCodeDownloader < ActionController::Base


  require 'nokogiri'
  require 'net/http'
  require 'yaml'

  def load_codes
    airports = YAML::load_file "airports.yml"
  end

  def download_codes_to_file
    #
    airports = self.airport_codes_from_A_to_Z
    File.open("airports.yml", "w") do |file|
      file.write airports.to_yaml
    end
  end

  def airport_codes_from_A_to_Z
    airports = {}
    "A".upto("Z") do |l|
#      puts 'Getting ICAO airports for: ' + l
      airports = airports.merge(self.download_code(l))
#      puts '  end processing: ' + l
    end
    airports
  end


  def download_code(first_letter)
    url = URI.parse('http://www.airlinecodes.co.uk/aptlistres.asp')
    req = Net::HTTP::Post.new(url.path)
    req.set_form_data('aptiata' => '',
                      'apticao'=> first_letter,
                      'submitletter' =>'Submit')

    res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      previous_node = nil
      airports = {}
      airport = {}
      first_node = false
      html_doc = Nokogiri::HTML(res.body)
      html_doc.xpath('//table/tr/td').each do | tr |
        if tr.text == 'IATA-Code:'
          first_node = true
        end
        if first_node 
          if previous_node
            airport[previous_node] = tr.text
            if previous_node == 'Country:'
              airports[airport['ICAO-Code:']] = airport

              airport = {}
            end
            previous_node = nil
          else
            previous_node = tr.text
          end
        end
      end    
      airports
    end
  end
end