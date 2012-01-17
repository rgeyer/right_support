require 'spec_helper'

describe RightSupport::Rack::CustomLogger do
  class OhNoes < Exception; end

  before(:all) do
    @app = flexmock('Rack app')
    @app.should_receive(:call).and_return([200, {}, 'body']).by_default
    @logger = flexmock(Logger)
  end

  context :initialize do
    context 'with 1 arg (app)' do
      it 'should succeed' do
        RightSupport::Rack::CustomLogger.new(@app)
      end
    end

    context 'with 2 args (app, logger)' do
      it 'should succeed' do
        RightSupport::Rack::CustomLogger.new(@app, @logger)
      end
    end

    context 'with 2 args (app, level)' do
      it 'should succeed' do
        RightSupport::Rack::CustomLogger.new(@app, Logger::INFO)
      end
    end

    context 'with 3 args (app, logger, level)' do
      it 'should succeed' do
        RightSupport::Rack::CustomLogger.new(@app, @logger, Logger::INFO)
      end
    end

    context 'with 3 args (app, level, logger)' do
      it 'should succeed' do
        RightSupport::Rack::CustomLogger.new(@app, Logger::INFO, @logger)
      end
    end
  end

  context :call do
    context 'when the app raises an exception' do
      before(:each) do
        @app.should_receive(:call).and_raise(OhNoes)
        @middleware = RightSupport::Rack::CustomLogger.new(@app, @logger)
      end

      it 'should log the exception' do
        @logger.should_receive(:error)
        lambda {
          @middleware.call({})
        }.should raise_error(OhNoes)
      end
    end

    context 'when Sinatra stores an exception' do
      before(:each) do
        @app.should_receive(:call).and_return([500, {}, 'body'])
        @env = {'sinatra.error' => OhNoes.new}
        @middleware = RightSupport::Rack::CustomLogger.new(@app, @logger)
      end

      it 'should log the exception' do
        @logger.should_receive(:error)
        @middleware.call(@env)
      end
    end
  end
end