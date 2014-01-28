# nagiosharder

Query and command a Nagios install using the power of ruby (and lots of screen-scaping)! Do the usual gem install jig:

    gem install nagiosharder

Now you have access to both a Ruby interface and a command line interface.

Here's some examples to get you started with the Ruby API:

    require 'nagiosharder'
    
    cgi         = 'http://path/to/nagios/cgi/directory'
    user        = 'user'
    pass        = 'pass'
    version     = 3
    time_format = 'iso8601'
    verify_ssl  = true
    
    site = NagiosHarder::Site.new(cgi, user, pass, version, time_format, verify_ssl)
    # version defaults to 3
    # time_format defaults to 'strict-iso8601' for version 3 and 'us' for all other versions
    # verify_ssl defaults to true, pass false to override

Get details back about a host's services:

    puts site.host_status('myhost')

Schedule a host to have services checks run again right now:

    site.schedule_host_check('myhost')

Get details on all services:

    site.service_status

Or just things with problems:

    site.service_status(
      :service_status_types => [
        :critical,
        :warning,
        :unknown
      ]
    )

Or just muted services, sorted desc by duration:

    site.service_status(
      :service_props => [
        :notifications_disabled,
      ],
      :sort_type    => :descending,
      :sort_option  => :state_duration,
    )

Or get the details for a single service group:

    site.service_status(:group => "AWESOME")

Schedule a host to have services checks run again right now:

    site.schedule_service_check('myhost', 'myservice')

Schedule 20 minutes of downtime, starting now:

    site.schedule_host_downtime('myhost', :start_time => Time.now, :end_time => Time.now + 20.minutes)

Schedule a flexible 20 minutes of downtime between now and 2 hours from now:

    site.schedule_host_downtime('myhost', :type => :flexible, :start_time => Time.now, :end_time => Time.now + 2.hours, :hours => 0, :minutes => 20)
  
Schedule 20 minutes of downtime for a service, starting now:

    site.schedule_service_downtime('myhost', 'myservice', :start_time => Time.now, :end_time => Time.now + 20.minutes)
  
Cancel a scheduled host downtime:

    site.cancel_downtime('downtime_id')
  
Cancel a scheduled service downtime:

    site.cancel_downtime('downtime_id', :service_downtime)

Acknowledge a down service:

    site.acknowledge_service('myhost', 'myservice', 'something bad happened')

Or unacknowledge a down service:

    site.unacknowledge_service('myhost', 'myservice')

Acknowledge a down host:

    site.acknowledge_host('myhost', 'something bad happened')
  
Or unacknowledge a down host:

    site.unacknowledge_host('myhost')
  
Schedule next host check for right now:

    site.schedule_host_check('myhost')
  
Schedule next service check for right now:

    site.schedule_service_check('myhost', 'myservice')

Disable notifications for a service:

    site.disable_service_notifications('myhost', 'myservice')

Check if notifications are disabled:

    site.service_notifications_disabled?('myhost', 'myservice')

Enable notifications for a service:

    site.enable_service_notifications('myhost', 'myservice')

Disable notifications, and wait for nagios to process it:

    site.disable_service_notifications('myhost', 'myservice')
    until site.service_notifications_disabled?('myhost', 'myservice')
      sleep 3
    end

Get a summary on all hostgroups:

    site.hostgroups_summary

Or a summary for a specific hostgroup:

    site.hostgroups_summary('myhostgroup')

Get a summary on all servicegroups:

    site.servicegroups_summary

Or a summary for a specific servicegroup:

    site.servicegroups_summary('myservicegroup')

Get detailed output for all hostgroups:

    site.hostgroups_detail

Get detailed output for a specific hostgroup:

    site.hostgroups_detail('myhostgroup')

Get alert history:

    site.alert_history

Or all HARD state alerts:

    site.alert_history(:state_type => :hard, :type => :all)

---

Then there's the command line. Start with --help

    nagiosharder --help

This will show you how you configure nagiosharder enough to talk to your nagios. You need at least a username, password, and nagios url. These can alternatively be in a config file.

For example:

    nagiosharder --config /path/to/yaml

This will display all available commands.

---

#### Note on Patches/Pull Requests

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a future version unintentionally.
* Commit, do not mess with rakefile, version, or history.  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

#### Copyright

Copyright (c) 2010 Josh Nichols. See LICENSE for details.