class NagiosHarder
  module Availability

    def host_availability(host, type = :up, stat = :pct_total)
      host_avail_url = "#{avail_url}?host=#{host}&timeperiod=last24hours&csvoutput=true&initialassumedservicestate=6"
      response =  get(host_avail_url)

      raise "wtf #{host_avail_url}? #{response.code}" unless response.code == 200

      avail_hash = parse_avail_html(response)

      return avail_hash       if type == :all
      return avail_hash[type] if stat == :all
      avail_hash[type][stat]
    end


    def service_availability(host, service, stat = :ok)
      service_hash = host_availability(host, :all)[:services][service]
      stat == :all ? service_hash :  service_hash[stat]
    end



    def avail_url
      "#{nagios_url}/avail.cgi"
    end

    private
    def name_from_element(e)
      if e.is_a? Nokogiri::XML::Text
        e.to_s
      else
        e.children.first.to_s
      end
    end

    def pct_from_element(e)
      e.to_s.to_f
    end

    def avail_hash_from_row(r)
      {
        time:       r[1].to_s,
        pct_total:  r[2].to_s.to_f,
        pct_known:  r[3].to_s.to_f
      }
    end

    def parse_avail_html(response)
      doc = Nokogiri::HTML(response.to_s)
      tables        = doc.css('table').to_a
      service_table = tables.pop
      host_table    = tables.pop

      services = Hashie::Mash.new.tap do |services|
        rows = service_table.css('tr').map(&:children)[1..-1]
        rows.each do |row|
          r = row.to_a.collect!(&:children).reverse.flatten!
          services[name_from_element(r.pop)] = Hashie::Mash.new({
            ok:           pct_from_element(r.pop),
            warning:      pct_from_element(r.pop),
            unknown:      pct_from_element(r.pop),
            critical:     pct_from_element(r.pop),
            undetermined: pct_from_element(r.pop)
            })
        end
      end

      Hashie::Mash.new.tap do |h|
        rows = host_table.css('tr').map(&:children)[1..-2]
        up_row      = rows[2].children.to_a
        down_row    = rows[5].children.to_a
        unreach_row = rows[8].children.to_a

        h[:up]           = avail_hash_from_row(up_row)
        h[:down]         = avail_hash_from_row(down_row)
        h[:unreachable]  = avail_hash_from_row(unreach_row)
        h[:services]     = services
      end
    end


  end
end