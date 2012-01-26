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
      it 'includes the description' do
        RightSupport::Log::ExceptionLogger.format_exception('desc').should == 'desc'
      end

      it 'includes the exception message if present' do
        e = ArgumentError.new("err")
        RightSupport::Log::ExceptionLogger.format_exception('desc', e).should =~ /desc \(ArgumentError: err.*/
      end

      it 'includes the exception string if present' do
        RightSupport::Log::ExceptionLogger.format_exception('desc', 'err', :no_trace).should == 'desc (err)'
      end

      context 'with backtrace=:no_trace' do
        it 'does not include a backtrace' do
          e = ArgumentError.new("err")
          RightSupport::Log::ExceptionLogger.format_exception('desc', e, :no_trace).should == 'desc (ArgumentError: err)'
        end
      end

      context 'with backtrace=:caller' do
        it 'includes a single line of backtrace' do
          begin
            raise ArgumentError.new("err")
          rescue Exception => e
            RightSupport::Log::ExceptionLogger.format_exception('desc', e, :caller).should == "desc (ArgumentError: err IN #{e.backtrace[0]})"
          end
        end

        it 'should default to :caller trace' do
          begin
            raise ArgumentError.new("err")
          rescue Exception => e
            RightSupport::Log::ExceptionLogger.format_exception('desc', e).should == "desc (ArgumentError: err IN #{e.backtrace[0]})"
          end
        end

        it 'excludes backtrace if the exception does not respond to backtrace' do
          RightSupport::Log::ExceptionLogger.format_exception('desc', 'err').should == "desc (err)"
        end
      end

      context 'with backtrace=:trace' do
        it 'includes a full backtrace' do
          begin
            raise ArgumentError.new("err")
          rescue Exception => e
            RightSupport::Log::ExceptionLogger.format_exception('desc', e, :trace).should == "desc (ArgumentError: err IN\n  " + e.backtrace.join("\n  ") + ")"
          end
        end

        it 'excludes backtrace if the exception does not respond to backtrace' do
          RightSupport::Log::ExceptionLogger.format_exception('desc', 'err').should == "desc (err)"
        end
      end
    end
  end
end