require 'spec_helper'

describe RightSupport::Net::HTTPClient do
  it 'has a distinct method for common HTTP verbs' do
    @http_client = RightSupport::Net::HTTPClient.new()
    @http_client.should respond_to(:get)
    @http_client.should respond_to(:post)
    @http_client.should respond_to(:put)
    @http_client.should respond_to(:delete)
  end

  context 'with defaults passed to initializer' do
    before(:all) do
      @http_client = RightSupport::Net::HTTPClient.new(:open_timeout=>999, :timeout=>101010,
                                                       :headers=>{:moo=>:bah})
    end
    
    context :process_query_string do
      it 'process nil url and params' do
         @http_client.instance_eval { process_query_string }.should == ''
      end
      it 'process empty String params' do
        url = '/moo'
        params = ''
        @http_client.instance_eval { process_query_string(url, params) }.should == '/moo'
      end
      it 'process params just with question mark' do
        url = '/moo'        
        params = '?'
        @http_client.instance_eval { process_query_string(url, params) }.should == '/moo'
      end
      it 'process String params with question mark in the beginning' do
        url = '/moo'
        params = '?a=b'
        @http_client.instance_eval { process_query_string(url, params) }.should == '/moo?a=b'
      end
      it 'process String params without question mark in the beginning' do
        url = '/moo'
        params = 'a=b&c=d'
        @http_client.instance_eval { process_query_string(url, params) }.should == '/moo?a=b&c=d'
      end

      context 'when converting with Addressable::URI' do
        it 'process raw Hash params' do
          url = '/moo'
          params = {:a=>:b}
          @http_client.instance_eval { process_query_string(url, params) }.should == '/moo?a=b'
        end
        it 'process Hash params with hash inside' do
          url = '/moo'
          params = {:a=>{:b=>:c}}
          @http_client.instance_eval { process_query_string(url, params) }.should == '/moo?a[b]=c'
        end
        it 'process Hash params with array inside' do
          url = '/moo'
          params = {:a=>['b','c']}
          @http_client.instance_eval { process_query_string(url, params) }.should == '/moo?a[0]=b&a[1]=c'
        end
        it 'process Hash params with nested array inside' do
          url = '/moo'
          params = {:a=>{:b=>:c,:d=>['e','f'],:g=>{:h=>'i'}},:j=>'k'}
          @http_client.instance_eval { process_query_string(url, params) }.should ==
              '/moo?a[b]=c&a[d][0]=e&a[d][1]=f&a[g][h]=i&j=k'
        end
      end

      context 'when converting directly' do
        before(:each) do
          flexmock(@http_client).should_receive(:require_succeeds?).with('addressable/uri').and_return(false)
        end

        it 'process raw Hash params' do
          url = '/moo'
          params = {:a=>:b}
          @http_client.instance_eval { process_query_string(url, params) }.should == '/moo?a=b'
        end
        it 'process Hash params with hash inside' do
          url = '/moo'
          params = {:a=>{:b=>:c}}
          @http_client.instance_eval { process_query_string(url, params) }.should == '/moo?a%5Bb%5D=c'
        end
        it 'process Hash params with array inside' do
          url = '/moo'
          params = {:a=>['b','c']}
          @http_client.instance_eval { process_query_string(url, params) }.should == '/moo?a%5B%5D=b&a%5B%5D=c'
        end
        it 'process Hash params with nested array inside' do
          url = '/moo'
          params = {:a=>{:b=>:c,:d=>['e','f'],:g=>{:h=>'i'}},:j=>'k'}
          @http_client.instance_eval { process_query_string(url, params) }.should ==
              '/moo?a%5Bb%5D=c&a%5Bd%5D%5B%5D=e&a%5Bd%5D%5B%5D=f&a%5Bg%5D%5Bh%5D=i&j=k'
        end
      end
    end

    context :request do
      it 'uses default options on every request' do
        p = {:method=>:get,
             :timeout=>101010,
             :open_timeout=>999,
             :url=>'/moo', :headers=>{:moo=>:bah}}
        flexmock(RestClient::Request).should_receive(:execute).with(p)
        @http_client.get('/moo')
      end

      it 'allows defaults to be overridden' do
        p = {:method=>:get,
             :timeout=>101010,
             :open_timeout=>3,
             :url=>'/moo', :headers=>{:joe=>:blow}}
        flexmock(RestClient::Request).should_receive(:execute).with(p)
        @http_client.get('/moo', :open_timeout=>3, :headers=>{:joe=>:blow})
      end
    end
  end

  context :request do
    before(:each) do
      r = 'this is a short mock REST response'
      flexmock(RestClient::Request).should_receive(:execute).and_return(r).by_default
      @http_client = RightSupport::Net::HTTPClient.new()
    end

    context 'given just a URL' do
      it 'succeeds' do
        p = {:method=>:get,
             :timeout=>RightSupport::Net::HTTPClient::DEFAULT_OPTIONS[:timeout],
             :open_timeout=>RightSupport::Net::HTTPClient::DEFAULT_OPTIONS[:open_timeout],
             :url=>'/moo', :headers=>{}}
        flexmock(RestClient::Request).should_receive(:execute).with(p)

        @http_client.get('/moo')
      end
    end

    context 'given a URL and headers' do
      it 'succeeds' do
        p = {:method=>:get,
             :timeout=>RightSupport::Net::HTTPClient::DEFAULT_OPTIONS[:timeout],
             :open_timeout=>RightSupport::Net::HTTPClient::DEFAULT_OPTIONS[:open_timeout],
             :url=>'/moo', :headers=>{:mrm=>1, :blah=>:foo}}
        flexmock(RestClient::Request).should_receive(:execute).with(p)

        @http_client.get('/moo', {:headers => {:mrm=>1, :blah=>:foo}})
      end
    end


    context 'given a timeout, no headers, and a URL' do
      it 'succeeds' do
        p = {:method=>:get,
             :timeout=>42,
             :open_timeout => RightSupport::Net::HTTPClient::DEFAULT_OPTIONS[:open_timeout],
             :url=>'/moo', :headers=>{}}
        flexmock(RestClient::Request).should_receive(:execute).with(p)

        @http_client.get('/moo', {:timeout => 42})
      end
    end
    
    context 'given a URL and any other parameters' do
      it 'succeeds' do
        p = { :method=>:get, :timeout=>RightSupport::Net::HTTPClient::DEFAULT_OPTIONS[:timeout],
              :url=>'/moo', :headers=>{},:open_timeout => 1, :payload=>{:foo => :bar} }
        flexmock(RestClient::Request).should_receive(:execute).with(p)

        @http_client.get('/moo', :open_timeout => 1, :payload=>{:foo => :bar})
      end
    end
  end
end
