require 'spec_helper'

describe RightSupport::Net::DNSResolver do
  before(:all) do
    @ips = ["1.2.3.4","5.6.7.8"]
    @info = [["AF_INET", 443, "amazonaws.com", @ips[0], 2, 1, 6], ["AF_INET", 443, "amazonaws.com", @ips[1], 2, 1, 6]]
    @hostname = "reposeX.rightscale.com"
    flexmock(Socket).should_receive(:getaddrinfo).with(@hostname, 443, Socket::AF_INET, Socket::SOCK_STREAM, Socket::IPPROTO_TCP).and_return(@info)
  end
  context 'with enabled SSLPatch' do
    before(:each) do
      RightSupport::Net::SSLPatch.enable!
    end
    after(:each) do
      RightSupport::Net::SSLPatch.disable!
    end
    it 'should register trusted dns name' do
      RightSupport::Net::DNSResolver.register_trusted_dns_name(@hostname)
      RightSupport::Net::DNSResolver.get_trusted_dns_name(@ips[0]).should eql(@hostname)
      RightSupport::Net::DNSResolver.get_trusted_dns_name(@ips[1]).should eql(@hostname)
    end
  end
  context 'with disabled SSLPatch' do
    it 'should NOT register a dns name' do
      RightSupport::Net::SSLPatch.enabled?.should be_false
      RightSupport::Net::DNSResolver.register_trusted_dns_name(@hostname)
      RightSupport::Net::DNSResolver.get_trusted_dns_name(@ips[0]).should be_nil
    end
  end
end

describe RightSupport::Net::SSLPatch do
  context 'standard workflow' do
    it 'enables monkey patch for OpenSSL' do
      RightSupport::Net::SSLPatch.enable!
      OpenSSL::SSL.should respond_to(:verify_certificate_identity_without_hack)
      RightSupport::Net::SSLPatch.enabled?.should be_true
    end
    it 'disables monkey patch for OpenSSL' do
      RightSupport::Net::SSLPatch.disable!
      RightSupport::Net::SSLPatch.enabled?.should be_false
    end
  end
  context :default do
    it 'should be disabled by default' do
      RightSupport::Net::SSLPatch.enabled?.should be_false
    end
  end
end
