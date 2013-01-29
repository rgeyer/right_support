require 'spec_helper'

describe RightSupport::Net::DNS do
  include SpecHelper::SocketMocking

  subject { RightSupport::Net::DNS } #the module itself

  context :resolve_all_ip_addresses do
    before(:all) do
      @hostnames = ['1.1.1.1', '2.2.2.2', '3.3.3.3']
      @hostnames .each do |hostname|
        flexmock(Socket).should_receive(:getaddrinfo).with(hostname, 443, Socket::AF_INET, Socket::SOCK_STREAM, Socket::IPPROTO_TCP).once.and_return([[0,0,0,hostname]])
      end
    end
    it 'resolves all ip addresses for specified array of endpoints' do
      @resolved_hostnames = subject.resolve_all_ip_addresses(@hostnames)
      (@resolved_hostnames - @hostnames).should be_eql([])
    end
  end


  context :resolve do
    context 'given default :retry => 3' do
      let(:endpoint) { 'www.example.com' }
      let(:output) { ['1.1.1.1', '2.2.2.2'] }

      it 'retries SocketError' do
        mock_getaddrinfo('www.example.com', SocketError)
        mock_getaddrinfo('www.example.com', ['1.1.1.1', '2.2.2.2'])

        subject.resolve(endpoint).should == output
      end

      it 'stops retrying SocketError after three attempts' do
        mock_getaddrinfo('www.example.com', SocketError, 3)

        expect { subject.resolve(endpoint) }.to raise_error(SocketError)
      end

      it 'does not rescue other exceptions' do
        mock_getaddrinfo('www.example.com', ArgumentError)

        expect { subject.resolve(endpoint) }.to raise_error(ArgumentError)
      end
    end

    context 'given :retry => 0' do
      it 'does not retry SocketError' do
        mock_getaddrinfo('www.example.com', SocketError)

        expect { subject.resolve('www.example.com', :retry=>0) }.to raise_error(SocketError)
      end
    end

    context 'given various endpoint formats' do
      context 'e.g. a DNS hostname' do
        let(:endpoint) { 'www.example.com' }
        let(:output) { ['1.1.1.1', '2.2.2.2'] }

        it 'resolves to IP addresses' do
          mock_getaddrinfo('www.example.com', ['1.1.1.1', '2.2.2.2'])
          subject.resolve(endpoint).should == output
        end
      end

      context 'e.g. an IPv4 address' do
        let(:endpoint) { '127.0.0.1' }
        let(:output) { ['127.0.0.1'] }

        it 'resolves to the same address' do
          mock_getaddrinfo('127.0.0.1', ['127.0.0.1'])
          subject.resolve(endpoint).should == output
        end
      end

      context 'e.g. an HTTP URL' do
        let(:endpoint) { 'http://www.example.com' }
        let(:output) { ['http://1.1.1.1', 'http://2.2.2.2'] }

        it 'resolves to URLs with addresses substituted' do
          mock_getaddrinfo('www.example.com', ['1.1.1.1', '2.2.2.2'])
          subject.resolve(endpoint).should == output
        end

        context 'with a path component' do
          let(:endpoint) { 'http://www.example.com/foo/bar' }
          let(:output) { ['http://1.1.1.1/foo/bar', 'http://2.2.2.2/foo/bar'] }

          it 'resolves to URLs with path component preserved' do
            mock_getaddrinfo('www.example.com', ['1.1.1.1', '2.2.2.2'])
            subject.resolve(endpoint).should == output
          end
        end
      end

      # The double slash in a URI indicates that an authority follows. The authority
      # is interpreted as a hostname for most URL schemes we are interested in. We
      # can't deal with URLs unless they have a clear authority/hostname that we
      # can substitute.
      #
      # For more information, see: http://tools.ietf.org/html/rfc3986#section-3
      context 'e.g. a URI without an authority' do
        let(:endpoint) { 'urn:uuid:6e8bc430-9c3a-11d9-9669-0800200c9a66' }

        it 'raises URI::InvalidURIError' do
          lambda do
            subject.resolve(endpoint)
          end.should raise_error(URI::InvalidURIError)
        end
      end

      context 'e.g. several hostnames' do
        let(:endpoints) { ['www.example.com', 'www.example.net'] }
        let(:output) { ['1.1.1.1', '2.2.2.2', '3.3.3.3', '4.4.4.4'] }

        it 'resolves to IP addresses' do
          mock_getaddrinfo('www.example.com', ['1.1.1.1', '2.2.2.2'])
          mock_getaddrinfo('www.example.net', ['3.3.3.3', '4.4.4.4'])

          subject.resolve(endpoints).sort.should == output
        end
      end

      context 'e.g. several HTTP URLs' do
        let(:endpoints) { ['http://www.example.com', 'http://www.example.net'] }
        let(:output) { ['http://1.1.1.1', 'http://2.2.2.2', 'http://3.3.3.3', 'http://4.4.4.4'] }

        it 'resolves to URLs with addresses substituted' do
          mock_getaddrinfo('www.example.com', ['1.1.1.1', '2.2.2.2'])
          mock_getaddrinfo('www.example.net', ['3.3.3.3', '4.4.4.4'])

          subject.resolve(endpoints).should == output
        end
      end
    end
  end
end
