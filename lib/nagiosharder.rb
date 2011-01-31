require 'restclient'
require 'nokogiri'
require 'active_support' # fine, we'll just do all of activesupport instead of the parts I want. thank Rails 3 for shuffling requires around.
require 'cgi'
require 'hashie'

# :(
require 'active_support/version' # double and triplely ensure ActiveSupport::VERSION is around
if ActiveSupport::VERSION::MAJOR > 2
  require 'active_support/core_ext/array'
  require 'active_support/core_ext/numeric/time'
  require 'active_support/core_ext/time/calculations'
  require 'active_support/core_ext/date/calculations'
  require 'active_support/core_ext/date_time/calculations'
  require 'active_support/core_ext/date/acts_like'
  require 'active_support/core_ext/time/acts_like'
  require 'active_support/core_ext/date_time/acts_like'
end

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

    def acknowledge_service(host, service, comment)
      # extra options: sticky_arg, send_notification, persistent
      
      request = {
        :cmd_typ => 34,
        :cmd_mod => 2,
        :com_author => @user,
        :com_data => comment,
        :host => host,
        :service => service
      }

      response = post(cmd_url, :body => request)
      response.code == 200 && response.body =~ /successful/
    end

    def unacknowledge_service(host, service)
      request = {
        :cmd_typ => 52,
        :cmd_mod => 2,
        :host => host,
        :service => service
      }
      
      response = post(cmd_url, :body => request)
      response.code == 200 && response.body =~ /successful/
    end

    def schedule_service_downtime(host, service, options = {})
      request = {
        :cmd_mod => 2,
        :cmd_typ => 56,
        :com_author => options[:author] || "#{@user} via nagiosharder",
        :com_data => options[:comment] || 'scheduled downtime by nagiosharder',
        :host => host,
        :service => service,
        :trigger => 0
      }

      request[:fixed] = case options[:type].to_sym
                        when :fixed then 1
                        when :flexible then 0
                        else 1
                        end


     if request[:fixed] == 0
        request[:hours]   = options[:hours]
        request[:minutes] = options[:minutes]
      end

      request[:start_time] = formatted_time_for(options[:start_time])
      request[:end_time]   = formatted_time_for(options[:end_time])

      response = post(cmd_url, :body => request)

      response.code == 200 && response.body =~ /successful/
    end

    def schedule_host_downtime(host, options = {})
      request = {
        :cmd_mod => 2,
        :cmd_typ => 55,
        :com_author => options[:author] || "#{@user} via nagiosharder",
        :com_data => options[:comment] || 'scheduled downtime by nagiosharder',
        :host => host,
        :childoptions => 0,
        :trigger => 0
      }

      # FIXME we could use some option checking...

      request[:fixed] = case options[:type].to_sym
                        when :fixed then 1
                        when :flexible then 0
                        else 1 # default to fixed
                        end

      if request[:fixed] == 0
        request[:hours]   = options[:hours]
        request[:minutes] = options[:minutes]
      end

      request[:start_time] = formatted_time_for(options[:start_time])
      request[:end_time]   = formatted_time_for(options[:end_time])

      response = post(cmd_url, :body => request)

      response.code == 200 && response.body =~ /successful/
    end
    
    # FIXME need to confirm this functionality exists in nagios
    #def cancel_downtime(downtime_id, downtime_type = :host_downtime)
    #  downtime_types = {
    #    :host_downtime => 78,
    #    :service_downtime => 79
    #  }
    #  response = post(cmd_url, :body => {
    #                                    :cmd_typ => downtime_types[downtime_type],
    #                                    :cmd_mod => 2,
    #                                    :down_id => downtime_id
    #                                    })
    #  response.code == 200 && response.body =~ /successful/
    #end
    
    def schedule_host_check(host)
      response = post(cmd_url, :body => {
                                          :start_time => formatted_time_for(Time.now),
                                          :host => host,
                                          :force_check => true,
                                          :cmd_typ => 96,
                                          :cmd_mod => 2
                                        })
      response.code == 200 && response.body =~ /successful/
    end

    def schedule_service_check(host, service)
      response = post(cmd_url, :body => {
                                          :start_time => formatted_time_for(Time.now),
                                          :host => host,
                                          :service => service,
                                          :force_check => true,
                                          :cmd_typ => 7,
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

      service_group = options[:group]


      params = {
        'hoststatustype' => 15,
        'servicestatustype' => service_status_type,
        'host' => 'all'
      }


      params = if @version == 3
                 [ "servicegroup=all", "style=detail" ]
               else
                 if service_group
                   ["servicegroup=#{service_group}", "style=detail"]
                 else
                   ["host=all"]
                 end
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

    def status_url
      "#{nagios_url}/status.cgi"
    end

    def cmd_url
      "#{nagios_url}/cmd.cgi"
    end

    def extinfo_url
      "#{nagios_url}/extinfo.cgi"
    end

    private


    def nagios_time_format
      if @version.to_i < 3
        "%m-%d-%Y %H:%M:%S"
      else
        "%Y-%m-%d %H:%M:%S"
      end
    end

    def formatted_time_for(time)
      time.strftime(time_format)
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

          if columns[1]
            service_links = columns[1].css('td a')
            service_link, other_links = service_links[0], service_links[1..-1]
            if service_links.size > 1
              comments_link = other_links.detect do |link|
                link.attribute('href').to_s =~ /#comments$/
              end
              comments_url = comments_link.attribute('href').to_s if comments_link

              flapping = other_links.any? do |link|
                link.css('img').attribute('src').to_s =~ /flapping\.gif/
              end

              acknowledged = other_links.any? do |link|
                link.css('img').attribute('src').to_s =~ /ack\.gif/
              end

              extra_service_notes_link = other_links.detect do |link|
                link.css('img').any? do |img|
                  img.attribute('src').to_s =~ /notes\.gif/
                end
              end
              extra_service_notes_url = extra_service_notes_link.attribute('href').to_s if extra_service_notes_link
            end

            service = service_links[0].inner_html
          end
          
          status = columns[2].inner_html  if columns[2]
          last_check = if columns[3]
                         require 'ruby-debug';
                         DateTime.strptime(columns[3].inner_html, nagios_time_format).to_time rescue breakpoint # nyoo
                       end
          duration = columns[4].inner_html.squeeze(' ').gsub(/^ /, '') if columns[4]
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

          if host && service && status && last_check && duration && attempts && started_at && status_info
            service_extinfo_url = "#{extinfo_url}?type=2&host=#{host}&service=#{CGI.escape(service)}"
            host_extinfo_url = "#{extinfo_url}?type=1&host=#{host}"

            status = Hashie::Mash.new :host => host,
              :host_extinfo_url => host_extinfo_url,
              :service => service,
              :status => status,
              :last_check => last_check,
              :duration => duration,
              :attempts => attempts,
              :started_at => started_at,
              :extended_info => status_info,
              :acknowledged => acknowledged,
              :service_extinfo_url => service_extinfo_url,
              :flapping => flapping,
              :comments_url => comments_url,
              :extra_service_notes_url => extra_service_notes_url

            yield status
          end
        end
      end

      nil
    end
    
  end

end
