require 'spec_helper'

describe RightSupport::Rack::RequestLogger do
  class OhNoes < Exception; end

  before(:each) do
    @app = flexmock('Rack app')
    @app.should_receive(:call).and_return([200, {}, 'body']).by_default
    @logger = mock_logger
    @env = {'rack.logger' => @logger}
    @middleware = RightSupport::Rack::RequestLogger.new(@app)
  end

  context :initialize do
    context 'without :logger option' do
      it 'uses rack.logger' do
        @logger.should_receive(:info)
        @middleware.call(@env).should == [200, {}, 'body']
      end
    end
  end

  context :call do
    context 'when the app raises an exception' do
      before(:each) do
        @app.should_receive(:call).and_raise(OhNoes)
      end

      it 'logs the exception' do
        @logger.should_receive(:error)
        lambda {
          @middleware.call({})
        }.should raise_error
      end
    end

    context 'when Sinatra stores an exception' do
      before(:each) do
        @app.should_receive(:call).and_return([500, {}, 'body'])
        @env['sinatra.error'] = OhNoes.new
      end

      it 'logs the exception' do
        @logger.should_receive(:info)
        @logger.should_receive(:error)
        @middleware.call(@env)
      end
    end

    context 'Shard ID logging' do
      before(:each) do
        @logger = mock_logger
      end

      it 'logs X-Shard header if it is present' do
        @env['HTTP_X_SHARD'] = '9'
        @logger.should_receive(:info).with(FlexMock.on { |arg| arg.should =~ /Shard: 9;/ } )
        @middleware.send(:log_request_begin, @logger, @env)
      end

      it 'logs "default" if X-Shard header is absent' do
        @logger.should_receive(:info).with(FlexMock.on { |arg| arg.should =~ /Shard: default;/ } )
        @middleware.send(:log_request_begin, @logger, @env)
      end
    end

  end
end
