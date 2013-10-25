require 'restclient'
require 'nokogiri'
require 'active_support' # fine, we'll just do all of activesupport instead of the parts I want. thank Rails 3 for shuffling requires around.
require 'cgi'
require 'hashie'
require 'nagiosharder/filters'
require 'nagiosharder/commands'

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
    attr_accessor :nagios_url, :user, :password, :default_options, :default_cookies, :version, :nagios_time_format
    include HTTParty::ClassMethods

    def initialize(nagios_url, user, password, version = 3, nagios_time_format = nil)
      @nagios_url = nagios_url.gsub(/\/$/, '')
      @user = user
      @password = password
      @default_options = {}
      @default_cookies = {}
      @version = version
      debug_output if ENV['DEBUG']
      basic_auth(@user, @password) if @user && @password
      @nagios_time_format = if nagios_time_format == 'us'
         "%m-%d-%Y %H:%M:%S"
      else
        if @version.to_i < 3
          "%m-%d-%Y %H:%M:%S"
        else
          "%Y-%m-%d %H:%M:%S"
        end
      end
      self
    end

    def post_command(body)
      # cmd_mod is always CMDMODE_COMMIT
      body = {:cmd_mod => 2}.merge(body)
      response = post(cmd_url, :body => body)
      response.code == 200 && response.body =~ /successful/
    end

    def acknowledge_service(host, service, comment)
      request = {
        :cmd_typ => COMMANDS[:acknowledge_service_problem],
        :com_author => @user,
        :com_data => comment,
        :host => host,
        :service => service,
        :send_notification => true,
        :persistent => false,
        :sticky_ack => true
      }

      post_command(request)
    end

    def acknowledge_host(host, comment)
      request = {
        :cmd_typ => COMMANDS[:acknowledge_host_problem],
        :com_author => @user,
        :com_data => comment,
        :host => host,
        :send_notification => true,
        :persistent => false,
        :sticky_ack => true
      }

      post_command(request)
    end

    def unacknowledge_service(host, service)
      request = {
        :cmd_typ => COMMANDS[:remove_service_acknowledgement],
        :host => host,
        :service => service
      }

      post_command(request)
    end

    def schedule_service_downtime(host, service, options = {})
      request = {
        :cmd_typ => COMMANDS[:schedule_service_downtime],
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

      post_command(request)
    end

    def schedule_host_downtime(host, options = {})
      request = {
        :cmd_typ => COMMANDS[:schedule_host_downtime],
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

      post_command(request)
    end

    def cancel_downtime(downtime_id, downtime_type = :host_downtime)
      request = {
        :cmd_typ => COMMANDS["del_#{downtime_type}".to_sym],
        :down_id => downtime_id
      }

      post_command(request)
    end

    def schedule_host_check(host)
      request = {
        :start_time => formatted_time_for(Time.now),
        :host => host,
        :force_check => true,
        :cmd_typ => COMMANDS[:schedule_host_check],
      }
      post_command(request)
    end

    def schedule_service_check(host, service)
      request = {
        :start_time => formatted_time_for(Time.now),
        :host => host,
        :service => service,
        :force_check => true,
        :cmd_typ => COMMANDS[:schedule_service_check],
      }
      post_command(request)
    end

    def service_status(options = {})
      params = {}

      {
        :host_status_types    => :notification_host,
        :service_status_types => :notification_service,
        :sort_type            => :sort,
        :sort_option          => :sort,
        :host_props           => :host,
        :service_props        => :service,
      }.each do |key, val|
        if options[key] && (options[key].is_a?(Array) || options[key].is_a?(Symbol))
          params[key.to_s.gsub(/_/, '')] = Nagiosharder::Filters.value(val, *options[key])
        end
      end

      # if any of the standard filter params are already integers, those win
      %w(
        :hoststatustypes,
        :servicestatustypes,
        :sorttype,
        :sortoption,
        :hostprops,
        :serviceprops,
      ).each do |key|
        params[key.to_s] = options[:val] if options[:val] && options[:val].match(/^\d*$/)
      end

      if @version == 3
        params['servicegroup'] = options[:group] || 'all'
        params['style'] = 'detail'
        params['embedded'] = '1'
        params['noheader'] = '1'
        params['limit'] = 0
      else
        if options[:group]
          params['servicegroup'] = options[:group]
          params['style'] = 'detail'
        else
          params['host'] = 'all'
        end
      end

      query = params.select {|k,v| v }.map {|k,v| "#{k}=#{v}" }.join('&')
      url = "#{status_url}?#{query}"
      response = get(url)

      raise "wtf #{url}? #{response.code}" unless response.code == 200

      statuses = []
      parse_status_html(response) do |status|
        statuses << status
      end

      statuses
    end

    def hostgroups_summary(options = {})
      hostgroups_summary_url = "#{status_url}?hostgroup=all&style=summary"
      response = get(hostgroups_summary_url)

      raise "wtf #{hostgroups_summary_url}? #{response.code}" unless response.code == 200

      hostgroups = {}
      parse_summary_html(response) do |status|
        hostgroups[status[:group]] = status
      end

     hostgroups
    end

    def servicegroups_summary(options = {})
      servicegroups_summary_url = "#{status_url}?servicegroup=all&style=summary"
      response = get(servicegroups_summary_url)

      raise "wtf #{servicegroups_summary_url}? #{response.code}" unless response.code == 200

      servicegroups = {}
      parse_summary_html(response) do |status|
        servicegroups[status[:group]] = status
      end

      servicegroups
    end

    def host_status(host)
      host_status_url = "#{status_url}?host=#{host}&embedded=1&noheader=1&limit=0"
      response =  get(host_status_url)

      raise "wtf #{host_status_url}? #{response.code}" unless response.code == 200

      services = {}
      parse_status_html(response) do |status|
        services[status[:service]] = status
      end

      services
    end

    def disable_service_notifications(host, service, options = {})
      request = {
        :host => host
      }

      if service
        request[:cmd_typ] = COMMANDS[:disable_service_notifications]
        request[:service] = service
      else
        request[:cmd_typ] = COMMANDS[:disable_host_service_checks]
        request[:ahas] = true
      end

      # TODO add option to block until the service shows as disabled
      post_command(request)
    end

    def enable_service_notifications(host, service, options = {})
      request = {
        :host => host
      }

      if service
        request[:cmd_typ] = COMMANDS[:enable_service_notifications]
        request[:service] = service
      else
        request[:cmd_typ] = COMMANDS[:enable_host_service_notifications]
        request[:ahas] = true
      end

      # TODO add option to block until the service shows as disabled
      post_command(request)
    end

    def service_notifications_disabled?(host, service)
      self.host_status(host)[service].notifications_disabled
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

    def formatted_time_for(time)
      time.strftime(nagios_time_format)
    end

    def parse_summary_html(response)
      doc = Nokogiri::HTML(response.to_s)
      rows = doc.css('table.status > tr')

      rows.each do |row|
        columns = Nokogiri::HTML(row.inner_html).css('body > td').to_a
        if columns.any?

          # Group column
          group = columns[0].inner_text.gsub(/\n/, '').match(/\((.*?)\)/)[1]
        end

        if group
          host_status_url, host_status_counts = parse_host_status_summary(columns[1]) if columns[1]
          service_status_url, service_status_counts = parse_service_status_summary(columns[2]) if columns[2]

          status = Hashie::Mash.new :group => group,
            :host_status_url => host_status_url,
            :host_status_counts => host_status_counts,
            :service_status_url => service_status_url,
            :service_status_counts => service_status_counts

          yield status
        end
      end
    end

    def parse_host_status_summary(column)
      text = column.css('td a')[0]
      link = text['href'] rescue nil
      counts = {}
      counts['up'] = column.inner_text.match(/(\d+)\s(UP)/)[1] rescue 0
      counts['down'] = column.inner_text.match(/(\d+)\s(DOWN)/)[1] rescue 0
      return link, counts
    end

    def parse_service_status_summary(column)
      text = column.css('td a')[0]
      link = text['href'] rescue nil
      counts = {}
      counts['ok'] = column.inner_text.match(/(\d+)\s(OK)/)[1] rescue 0
      counts['warning'] = column.inner_text.match(/(\d+)\s(WARNING)/)[1] rescue 0
      counts['critical'] = column.inner_text.match(/(\d+)\s(CRITICAL)/)[1] rescue 0
      counts['unknown'] = column.inner_text.match(/(\d+)\s(UNKNOWN)/)[1] rescue 0
      return link, counts
    end

    def parse_status_html(response)
      doc = Nokogiri::HTML(response.to_s)
      rows = doc.css('table.status > tr')

      last_host = nil
      rows.each do |row|
        columns = Nokogiri::HTML(row.inner_html).css('body > td').to_a
        if columns.any?

          # Host column
          host = columns[0].inner_text.gsub(/\n/, '')

          # for a given host, the host details are blank after the first row
          if host != ''
            # remember it for next time
            last_host = host
          else
            # or save it for later
            host = last_host
          end
          debug 'parsed host column'

          # Service Column
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

              notifications_disabled = other_links.any? do |link|
                link.css('img').attribute('src').to_s =~ /ndisabled\.gif/
              end

              downtime = other_links.any? do |link|
                link.css('img').attribute('src').to_s =~ /downtime\.gif/
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
          debug 'parsed service column'

          # Status
          status = columns[2].inner_html  if columns[2]
          debug 'parsed status column'

          # Last Check
          last_check = if columns[3] && columns[3].inner_html != 'N/A'
                         last_check_str = columns[3].inner_html
                         debug "Need to parse #{columns[3].inner_html} in #{nagios_time_format}"
                         DateTime.strptime(columns[3].inner_html, nagios_time_format).to_s
                       end
          debug 'parsed last check column'

          # Duration
          duration = columns[4].inner_html.squeeze(' ').gsub(/^ /, '') if columns[4]
          started_at = if duration && match_data = duration.match(/^\s*(\d+)d\s+(\d+)h\s+(\d+)m\s+(\d+)s\s*$/)
                         (
                           match_data[1].to_i.days +
                           match_data[2].to_i.hours +
                           match_data[3].to_i.minutes +
                           match_data[4].to_i.seconds
                         ).ago
                       end
          debug 'parsed duration column'

          # Attempts
          attempts = columns[5].inner_html if columns[5]
          debug 'parsed attempts column'

          # Status info
          status_info = columns[6].inner_html.gsub('&nbsp;', '').gsub("\302\240", '') if columns[6]
          debug 'parsed status info column'


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
              :extra_service_notes_url => extra_service_notes_url,
              :notifications_disabled => notifications_disabled,
              :downtime => downtime

            yield status
          end
        end
      end

      nil
    end

    def debug(*args)
      $stderr.puts *args if ENV['DEBUG']
    end

  end
end
