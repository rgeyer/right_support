require 'spec_helper'

describe RightSupport::Log::ExceptionLogger do
  before(:all) do
    @actual_logger = Logger.new(StringIO.new)
    @logger = RightSupport::Log::ExceptionLogger.new(@actual_logger)
    @exception = Exception.new('message')
  end

  context :exception do
    it 'logs an error with exception information' do
      flexmock(@actual_logger).should_receive(:fatal)
      @logger.exception('desc', @exception)
    end
  end

  context 'class methods' do
    context :format_exception do
      it 'includes the description'
      it 'includes the exception message if present'

      context 'with backtrace=:no_trace' do
        it 'does not include a backtrace'
      end

      context 'with backtrace=:caller' do
        it 'includes a single line of backtrace'
      end

      context 'with backtrace=:trace' do
        it 'includes a full backtrace'
      end
    end
  end
end