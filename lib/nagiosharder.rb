require 'restclient'
require 'nokogiri'
require 'active_support/core_ext/array'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/time/calculations'
require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/date_time/calculations'
require 'active_support/core_ext/date/acts_like'
require 'active_support/core_ext/time/acts_like'
require 'active_support/core_ext/date_time/acts_like'
require 'httparty'

class NagiosHarder
  class Site
    attr_accessor :nagios_url, :user, :password, :default_options, :default_cookies, :version
    include HTTParty::ClassMethods

    def initialize(nagios_url, user, password, version = 3)
      @nagios_url = nagios_url.gsub(/\/$/, '')
      @user = user
      @password = password
      @default_options = {}
      @default_cookies = {}
      @version = version
      basic_auth(@user, @password) if @user && @password
    end

    def status_url
      "#{nagios_url}/status.cgi"
    end

    def cmd_url
      "#{nagios_url}/cmd.cgi"
    end

    def schedule_downtime(host)
      response = post(cmd_url, :body => {
                                          :cmd_typ => 55,
                                          :cmd_mod => 2,
                                          :host => host, # host name
                                          :com_author => 'nagiosharder', # author
                                          :com_data => 'maintenance', # comment
                                          :trigger => '0', # n/a
                                          :start_time => formatted_time_for(Time.now),
                                          :end_time => formatted_time_for(Time.now + 7200),
                                          :fixed => '1', # 1 for true or 0 for false
                                          :hours => '2', # if flexible
                                          :minutes => '0' # if flexible
                                        })
      response.code == 200 && response.body =~ /successful/
    end
    
    def cancel_downtime(downtime_id, downtime_type = :host_downtime)
      downtime_types = {
        :host_downtime => 78,
        :service_downtime => 79
      }
      response = post(cmd_url, :body => {
                                        :cmd_typ => downtime_types[downtime_type],
                                        :cmd_mod => 2,
                                        :down_id => downtime_id
                                        })
      response.code == 200 && response.body =~ /successful/
    end
    
    def schedule_service_check(host)
      response = post(cmd_url, :body => {
                                          :start_time => Time.now,
                                          :host => host,
                                          :force_check => true,
                                          :cmd_typ => 92,
                                          :cmd_mod => 2
                                        })
      response.code == 200 && response.body =~ /successful/
    end

    def service_status(type, options = {})
      service_status_type = case type
                            when :ok then 2
                            when :warning then 4
                            when :unknown then 8
                            when :critical then 16
                            when :pending then 1
                            when :all_problems then 28
                            when :all then nil
                            else
                              raise "Unknown type"
                            end

      sort_type = case options[:sort_type]
                  when :asc then 1
                  when :desc then 2
                  when nil then nil
                  else
                    raise "Invalid options[:sort_type]"
                  end

      sort_option = case options[:sort_option]
                    when :host then 1
                    when :service then 2
                    when :status then 3
                    when :last_check then 4
                    when :duration then 6
                    when :attempts then 5
                    when nil then nil
                    else
                      raise "Invalid options[:sort_option]"
                    end


      params = {
        'hoststatustype' => 15,
        'servicestatustype' => service_status_type,
        'host' => 'all'
      }


      params = if @version == 3
                 [ "servicegroup=all", "style=detail" ]
               else
                 [ "host=all" ]
               end
      params += [
                  service_status_type ? "servicestatustypes=#{service_status_type}" : nil,
                  sort_type ? "sorttype=#{sort_type}" : nil,
                  sort_option ? "sortoption=#{sort_option}" : nil,
                  "hoststatustypes=15"
                ]
      query = params.compact.join('&')
      url = "#{status_url}?#{query}"
      response = get(url)

      raise "wtf #{url}? #{response.code}" unless response.code == 200

      statuses = []
      parse_status_html(response) do |status|
        statuses << status
      end

      statuses
    end

    def host_status(host)
      host_status_url = "#{status_url}?host=#{host}"
      response =  get(host_status_url)

      raise "wtf #{host_status_url}? #{response.code}" unless response.code == 200

      services = {}
      parse_status_html(response) do |status|
        services[status[:service]] = status
      end

      services
    end

    private

    def formatted_time_for(time)
      if @version.to_i < 3
        time.strftime("%m-%d-%Y %H:%M:%S")
      else 
        time.strftime("%Y-%m-%d %H:%M:%S")
      end
    end

    def parse_status_html(response)
      doc = Nokogiri::HTML(response)
      rows = doc.css('table.status > tr')

      last_host = nil
      rows.each do |row|
        columns = Nokogiri::HTML(row.inner_html).css('body > td').to_a
        if columns.any?

          host = columns[0].inner_text.gsub(/\n/, '')

          # for a given host, the host details are blank after the first row
          if host != ''
            # remember it for next time
            last_host = host
          else
            # or save it for later
            host = last_host
          end

          service = columns[1].inner_text.gsub(/\n/, '') if columns[1]
          status = columns[2].inner_html  if columns[2]
          last_check = columns[3].inner_html if columns[3]
          duration = columns[4].inner_html if columns[4]
          started_at = if duration && match_data = duration.match(/^\s*(\d+)d\s+(\d+)h\s+(\d+)m\s+(\d+)s\s*$/)
                         (
                           match_data[1].to_i.days +
                           match_data[2].to_i.hours +
                           match_data[3].to_i.minutes +
                           match_data[4].to_i.seconds
                         ).ago

                       end
          attempts = columns[5].inner_html if columns[5]
          status_info = columns[6].inner_html.gsub('&nbsp;', '') if columns[6]

          status = {
            :host => host,
            :service => service,
            :status => status,
            :last_check => last_check,
            :duration => duration,
            :attempts => attempts,
            :started_at => started_at,
            :extended_info => status_info
          }

          if host && service && status && last_check && duration && attempts && started_at && status_info
            yield status
          end
        end
      end

      nil
    end
    
  end
end
