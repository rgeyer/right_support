require 'spec_helper'

describe RightSupport::Net::DNS do
  context :resolve_all_ip_addresses do
    before(:all) do
      @hostnames = ['1.1.1.1','2.2.2.2','3.3.3.3']
      @hostnames .each do |hostname|
        flexmock(Socket).should_receive(:getaddrinfo).with(hostname, 443, Socket::AF_INET, Socket::SOCK_STREAM, Socket::IPPROTO_TCP).once.and_return([[0,0,0,hostname]])
      end
    end
    it 'resolves all ip addresses for specified array of endpoints' do
      @resolved_hostnames = RightSupport::Net::DNS.resolve_all_ip_addresses(@hostnames)
      (@resolved_hostnames - @hostnames).should be_eql([])
    end
  end
end
