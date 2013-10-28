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
end
