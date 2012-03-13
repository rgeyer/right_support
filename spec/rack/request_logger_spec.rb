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

      it 'should log the exception' do
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

      it 'should log the exception' do
        @logger.should_receive(:info)
        @logger.should_receive(:error)
      end
    end
  end
end