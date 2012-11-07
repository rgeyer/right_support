=begin

Copyright (c) 2012, Nathaniel Ritmeyer
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

3. Neither the name Nathaniel Ritmeyer nor the names of contributors to
this software may be used to endorse or promote products derived from this
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Modified for use with RightSupport CI.

=end

require 'time'
require 'builder'

module RightSupport::CI
  if require_succeeds?('rspec/core/formatters/base_formatter')
    # RSpec 2
    base_class = RSpec::Core::Formatters::BaseFormatter
  elsif require_succeeds?('spec/runner/formatter/base_formatter')
    # RSpec 1
    base_class = Spec::Runner::Formatter::BaseTextFormatter
  end

  class JUnitRSpecFormatter < base_class
    def initialize(*args)
      super(*args)
      @test_results = []
    end

    def example_passed(example)
      @test_results << example
    end

    def example_failed(example)
      @test_results << example
    end

    def example_pending(example)
      @test_results << example
    end

    def failure_details_for(example)
      exception = example.exception
      exception.nil? ? "" : "#{exception.message}\n#{format_backtrace(exception.backtrace, example).join("\n")}"
    end

    def classname_for(example)
      eg = example.metadata[:example_group]
      eg = eg[:example_group] while eg.key?(:example_group)
      klass = eg[:description_args].to_s
      "rspec.#{klass}"
    end

    def dump_summary(duration, example_count, failure_count, pending_count)
      builder = Builder::XmlMarkup.new :indent => 2
      builder.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
      builder.testsuite :errors => 0, :failures => failure_count, :skipped => pending_count, :tests => example_count, :time => duration, :timestamp => Time.now.iso8601 do
        builder.properties
        @test_results.each do |test|
          classname        = classname_for(test)
          full_description = test.full_description
          time             = test.metadata[:execution_result][:run_time]

          # The full description always begins with the classname, but this is useless info when
          # generating the XML report.
          if full_description.start_with?(classname)
            full_description = full_description[classname.length..-1].strip
          end

          builder.testcase(:classname => classname, :name => full_description, :time => time) do
            case test.metadata[:execution_result][:status]
            when "failed"
              builder.failure :message => "failed #{test.metadata[:full_description]}", :type => "failed" do
                builder.cdata! failure_details_for test
              end
            when "pending" then
              builder.skipped
            end
          end
        end
      end
      output.puts builder.target!
    end
  end
end
