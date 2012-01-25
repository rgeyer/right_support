require 'spec_helper'

describe RightSupport::Rack::CustomLogger do
  class OhNoes < Exception; end

  before(:all) do
    @app = flexmock('Rack app')
    @app.should_receive(:call).and_return([200, {}, 'body']).by_default
    @logger = mock_logger
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
end