require 'terminal-table'
class NagiosHarder
  class Cli
    def self.service_table
      table = Terminal::Table.new(:headings => ['Service', 'Status', 'Details']) do |t|
        yield(t)
      end
      table.align_column(1, :right)
      puts table
    end

    def self.service_row(service)
      service['status'] << "/ACK" if service['acknowledged']
      service['status'] << "/MUTE" if service['notifications_disabled']
      service['status'] << "/COMMENT" if service['comments_url']
      [
        service['host']+"/"+service["service"],
        service['status'],
        wrap_text(service['extended_info'], 40)
      ]
    end
  end
end