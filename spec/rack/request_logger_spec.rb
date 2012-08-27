require 'spec_helper'

describe RightSupport::Rack::RequestLogger do
  class OhNoes < Exception; end

  before(:all) do
    @app = flexmock('Rack app')
    @app.should_receive(:call).and_return([200, {}, 'body']).by_default
    @logger = mock_logger
  end

  context :initialize do
    context 'without :logger option' do
      it 'uses rack.logger' do
        env = {'rack.logger' => @logger}
        middleware = RightSupport::Rack::RequestLogger.new(@app)
        @logger.should_receive(:info)
        middleware.call(env).should == [200, {}, 'body']
      end
    end
  end

  context :call do
    context 'when the app raises an exception' do
      before(:each) do
        @app.should_receive(:call).and_raise(OhNoes)
        @middleware = RightSupport::Rack::RequestLogger.new(@app)
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
        @env = {'sinatra.error' => OhNoes.new}
        @middleware = RightSupport::Rack::RequestLogger.new(@app)
      end

      it 'logs the exception' do
        @logger.should_receive(:info)
        @logger.should_receive(:error)
      end
    end

    context 'Shard_id logging' do
      before(:each) do
        @middleware = RightSupport::Rack::RequestLogger.new(@app)
        @logger = mock_logger
      end

      it 'logs if shard_id exists' do
        env = {'rack.logger' => @logger, 'HTTP_X_SHARD' => '9'}
        @logger.should_receive(:info).with(FlexMock.on { |arg| arg.should =~ /Shard_id: 9;/ } )
        @middleware.send(:log_request_begin, @logger, env)
      end

      it 'does not log if shard_id does not exist' do
        env = {'rack.logger' => @logger}
        @logger.should_receive(:info).with(FlexMock.on { |arg| arg.match(/Shard_id: 9;/).should == nil } )
        @middleware.send(:log_request_begin, @logger, env)
      end
    end

  end
end
