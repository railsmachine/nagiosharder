require 'spec_helper'

describe 'NagiosHarder::Site' do
  let(:client) do
    client = NagiosHarder::Site.new(ENV['NAGIOS_URL']      || "",
                                    ENV['NAGIOS_USER']     || "",
                                    ENV['NAGIOS_PASSWORD'] || "")
    client.stub(:post)
    client
  end

  let(:successful_response) do
    Class.new() do
      def code
        200
      end

      def body
        "successful"
      end
    end.new
  end

  it 'should initialize' do
    client
  end

  it 'should call post in post_command' do
    client.should_receive(:post) do |url, params|
      params[:body][:foo].should == :bar
      # Return an instance that makes the rest of the method work
      successful_response
    end

    client.post_command({:foo => :bar}).should == true
  end

  it 'should let you acknowledge a service' do
    client.should_receive(:post_command) do |params|
      params[:host].should       == 'example.com'
      params[:service].should    == 'http'
      params[:com_data].should   == 'Looking'
      params[:com_author].should == client.user
      params[:cmd_typ].should    == 34
    end

    client.acknowledge_service('example.com', 'http', 'Looking')
  end

  it 'should let you acknowledge a host' do
    client.should_receive(:post_command) do |params|
      params[:host].should       == 'example.com'
      params[:com_data].should   == 'Looking'
      params[:com_author].should == client.user
      params[:cmd_typ].should    == 33
    end

    client.acknowledge_host('example.com', 'Looking')
  end

  it 'should let you unacknowledge a service' do
    client.should_receive(:post_command) do |params|
      params[:host].should       == 'example.com'
      params[:service].should    == 'http'
      params[:cmd_typ].should    == 52
    end

    client.unacknowledge_service('example.com', 'http')
  end

  it 'should let you schedule service downtime' do
    client.should_receive(:post_command) do |params|
      params[:host].should       == 'example.com'
      params[:service].should    == 'http'
      params[:cmd_typ].should    == 56
      params[:com_author].should_not be_blank
      params[:com_data].should_not   be_blank
    end

    client.schedule_service_downtime('example.com', 'http')
  end

  it 'should let you schedule host downtime' do
    client.should_receive(:post_command) do |params|
      params[:host].should       == 'example.com'
      params[:cmd_typ].should    == 55
      params[:com_author].should_not be_blank
      params[:com_data].should_not   be_blank
    end

    client.schedule_host_downtime('example.com')
  end

  it 'should let you cancel downtime' do
    client.should_receive(:post_command) do |params|
      params[:cmd_typ].should == 78
      params[:down_id].should == 0
    end

    client.cancel_downtime(0)
  end

  it 'should let you schedule a host check' do
    client.should_receive(:post_command) do |params|
      params[:host].should        == 'example.com'
      params[:cmd_typ].should     == 96
      params[:force_check].should == true
    end

    client.schedule_host_check('example.com')
  end

  it 'should let you schedule a service check' do
    client.should_receive(:post_command) do |params|
      params[:host].should        == 'example.com'
      params[:service].should     == 'http'
      params[:cmd_typ].should     == 7
      params[:force_check].should == true
    end

    client.schedule_service_check('example.com','http')
  end
end
