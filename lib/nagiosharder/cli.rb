require 'terminal-table'
require 'optparse'
require 'nagiosharder'

class NagiosHarder
  class Cli

    attr_reader :options, :command, :param, :the_rest, :host, :service

    def initialize(argv)
      @options          = parse_connection_options(argv)
      @command, @param  = argv
      @host, @service   = param.split("/") if param
      @the_rest         = argv[2..-1]
    end

    def run
      return_value = case command
      when 'status'
        service_table do
          client.host_status(host).select do |name, s|
            service.nil? || service == name
          end.map { |name, s| s }
        end
        true
      when /^(ack|acknowledged)$/
        if service.nil?
          client.acknowledge_host(host, the_rest.join(' '))
        else
          client.acknowledge_service(host, service, the_rest.join(' '))
        end
      when /^unack/
        client.unacknowledge_service(host, service)
      when /^(mute|disable_notifications)$/
        client.disable_service_notifications(host, service)
      when /^(unmute|enable_notifications)$/
        client.enable_service_notifications(host, service)
      when 'check'
        if service
          client.schedule_service_check(host, service)
        else
          client.schedule_host_check(host)
        end
      when 'downtime'
        if service
          client.schedule_service_downtime(host, service, :type => :fixed, :start_time => Time.now, :end_time => Time.now + the_rest.first.to_i.minutes)
        else
          client.schedule_host_downtime(host, :type => :fixed, :start_time => Time.now, :end_time => Time.now + the_rest.first.to_i.minutes)
        end
      when 'problems'
        service_table do
          params = {
            :service_status_types => [:critical, :warning, :unknown],
          }
          params[:group] = param
          client.service_status(params)
        end
        true
      when /^(critical|warning|unknown)/
        service_table do
          params = {
            :service_status_types => [
              $1,
            ],
            :service_props => [
              :hard_state,
              :no_scheduled_downtime,
              :state_unacknowledged,
              :notifications_enabled
            ]
          }
          params[:group] = param
          client.service_status(params)
        end
        true
      when /^(triage|unhandled)/
        service_table do
          params = {
            :service_status_types => [
              :critical,
              :warning,
              :unknown
            ],
            :host_props => [
              :no_scheduled_downtime,
              :state_unacknowledged,
              :notifications_enabled
            ],
            :service_props => [
              :no_scheduled_downtime,
              :state_unacknowledged,
              :notifications_enabled
            ]
          }
          params[:group] = param
          client.service_status(params)
        end
        true
      when /^muted/
        service_table do
          params = {
            :service_props => [
              :notifications_disabled,
            ]
          }
          params[:group] = param
          client.service_status(params)
        end
        true
      when /^(acked|acknowledged)/
        service_table do
          params = {
            :service_status_types => [
              :critical,
              :warning,
              :unknown
            ],
            :service_props => [
              :state_acknowledged,
            ]
          }
          params[:group] = param
          client.service_status(params)
        end
        true
      else
        debug "'#{command}'"
        raise ArgumentError, help
      end
      if return_value
        0
      else
        puts "Sorry, bro, nagios didn't like that."
        1
      end
    end

    protected

    def client
      debug "loading client with options #{options.inspect}"
      @client ||= NagiosHarder::Site.new(options['nagios_url'], options['user'], options['password'], options['version'], options['time'])
    end

    def parse_connection_options(argv)
      options = {
        'version' => 3
      }

      optparse = OptionParser.new do |opts|
        opts.banner = "Usage: nagiosharder [options] [command]"

        opts.on( '-h', '--help') do
          raise ArgumentError, opts.help
        end

        opts.on( '-c', '--config [/path/to/file]', 'YAML config file [optional, but recommended]') do |file|
          options.merge!(YAML.load_file(file))
        end

        opts.on( '-u', '--user USER', 'Nagios user') do |user|
          options['user'] = user
        end

        opts.on( '-p', '--password PASSWORD', 'Nagios password') do |password|
          options['password'] = password
        end

        opts.on( '-n', '--nagios_url URL', 'Nagios cgi url') do |nagios_url|
          options['nagios_url'] = nagios_url
        end

        opts.on( '-v', '--version [3]', 'Nagios version (2 or 3, defaults to 3)') do |version|
          options['version'] = version
        end

        opts.on( '-t', '--time [us|euro]', 'Nagios time format') do |time|
          options['time'] = time
        end

      end

      begin
        optparse.parse!(argv)
      rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
        raise ArgumentError, e.message + "\n\n" + optparse.help
      end

      unless options['nagios_url'] && options['user'] && options['password']
        raise ArgumentError, optparse.help
      end

      options
    end

    def service_table
      table = Terminal::Table.new(:headings => ['Service', 'Status', 'Details']) do |t|
        services = yield
        services.each do |service|
          t << service_row(service)
        end
        t
      end
      table.align_column(1, :right)
      puts table
    end

    def service_row(service)
      service['status'] << "/ACK" if service['acknowledged']
      service['status'] << "/MUTE" if service['notifications_disabled']
      service['status'] << "/COMMENT" if service['comments_url']
      [
        service['host']+"/"+service["service"],
        service['status'],
        wrap_text(service['extended_info'], 40)
      ]
    end

    # wraps text at the specified column, 80 by default
    def wrap_text(txt, col = 80)
      txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
        "\\1\\3\n")
    end

    def debug(*args)
      $stderr.puts *args if ENV['DEBUG']
    end

    def help
      help = <<-HELP
NagiosHarder

USAGE:

  nagiosharder --help
  nagiosharder [options] [command]

COMMANDS:

    nagiosharder commands

    nagiosharder status aux1
    nagiosharder status aux1/http

    nagiosharder acknowledge aux1 [message]

    nagiosharder acknowledge aux1/http [message]
    nagiosharder ack aux1/http [message]

    nagiosharder unacknowledge aux1/http
    nagiosharder unack aux1/http

    nagiosharder mute aux1
    nagiosharder mute aux1/http
    nagiosharder disable_notifications aux1/http

    nagiosharder unmute aux1
    nagiosharder unmute aux1/http
    nagiosharder enable_notifications aux1/http

    nagiosharder check aux1/http

    nagiosharder downtime aux1 15
    nagiosharder downtime aux1/http 15

    nagiosharder problems
    nagiosharder problems http-services

    nagiosharder acknowledged
    nagiosharder acked http-services

    nagiosharder muted
    nagiosharder muted http-services

    nagiosharder triage
    nagiosharder unhandled
    nagiosharder unhandled http-services
      HELP
    end
  end
end
