describe RightSupport::Log::ExceptionLogging do
  before(:all) do
    @logger = Logger.new(StringIO.new)
    @exception = Exception.new('message')
  end

  context 'methods added to Logger' do
    context :exception do
      it 'logs an error with exception information' do
        flexmock(@logger).should_receive(:error)
        @logger.exception('desc', @exception)
      end
    end

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