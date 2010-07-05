require 'httparty'
require 'nokogiri'
require 'activesupport'

class NagiosHarder
  include HTTParty
  basic_auth ENV['NAGIOS_USER'], ENV['NAGIOS_PASSWORD']

  class << self
    def base_url
      ENV['NAGIOS_URL'] || @base_url
    end

    def base_url=(url)
      @base_url = url
    end
  end

  def self.host_status(host)
    response =  get("#{base_url}/status.cgi?host=#{host}")
    doc = Nokogiri::HTML(response)
    rows = doc.css('table.status > tr > td').to_a.in_groups_of(7)

    rows.inject({}) do |services, row|
      service = row[1].inner_text.gsub(/\n/, '')
      status = row[2].inner_html
      last_check = row[3].inner_html
      duration = row[4].inner_html
      started_at = if match_data = duration.match(/^\s*(\d+)d\s+(\d+)h\s+(\d+)m\s+(\d+)s\s*$/)
                     (
                       match_data[1].to_i.days +
                       match_data[2].to_i.hours +
                       match_data[3].to_i.minutes +
                       match_data[4].to_i.seconds
                     ).ago

                   end
      attempts = row[5].inner_html
      status_info = row[6].inner_html.gsub('&nbsp;', '')

      services[service] = {
        :status => status,
        :last_check => last_check,
        :duration => duration,
        :attempts => attempts,
        :started_at => started_at,
        :extended_info => status_info
      }

      services
    end
  end
end
