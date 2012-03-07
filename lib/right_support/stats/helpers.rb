# Copyright (c) 2009-2012 RightScale Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module RightSupport

  # Helper functions that are useful when gathering or displaying statistics
  module Stats

    # Maximum characters in stat name
    MAX_STAT_NAME_WIDTH = 11

    # Maximum characters in sub-stat name
    MAX_SUB_STAT_NAME_WIDTH = 17

    # Maximum characters in sub-stat value line
    MAX_SUB_STAT_VALUE_WIDTH = 80

    # Maximum characters displayed for exception message
    MAX_EXCEPTION_MESSAGE_WIDTH = 60

    # Separator between stat name and stat value
    SEPARATOR = " : "

    # Time constants
    MINUTE = 60
    HOUR = 60 * MINUTE
    DAY = 24 * HOUR

    # Convert 0 value to nil
    # This is in support of displaying "none" rather than 0
    #
    # === Parameters
    # value(Integer|Float):: Value to be converted
    #
    # === Returns
    # (Integer|Float|nil):: nil if value is 0, otherwise the original value
    def self.nil_if_zero(value)
      value == 0 ? nil : value
    end

    # Convert values hash into percentages
    #
    # === Parameters
    # values(Hash):: Values to be converted whose sum is the total for calculating percentages
    #
    # === Return
    # (Hash):: Converted values with keys "total" and "percent" with latter being a hash with values as percentages
    def self.percentage(values)
      total = 0
      values.each_value { |v| total += v }
      percent = {}
      values.each { |k, v| percent[k] = (v / total.to_f) * 100.0 } if total > 0
      {"percent" => percent, "total" => total}
    end

    # Convert elapsed time in seconds to displayable format
    #
    # === Parameters
    # time(Integer|Float):: Elapsed time
    #
    # === Return
    # (String):: Display string
    def self.elapsed(time)
      time = time.to_i
      if time <= MINUTE
        "#{time} sec"
      elsif time <= HOUR
        minutes = time / MINUTE
        seconds = time - (minutes * MINUTE)
        "#{minutes} min #{seconds} sec"
      elsif time <= DAY
        hours = time / HOUR
        minutes = (time - (hours * HOUR)) / MINUTE
        "#{hours} hr #{minutes} min"
      else
        days = time / DAY
        hours = (time - (days * DAY)) / HOUR
        minutes = (time - (days * DAY) - (hours * HOUR)) / MINUTE
        "#{days} day#{days == 1 ? '' : 's'} #{hours} hr #{minutes} min"
      end
    end

    # Determine enough precision for floating point value(s) so that all have
    # at least two significant digits and then convert each value to a decimal digit
    # string of that precision after applying rounding
    # When precision is wide ranging, limit precision of the larger numbers
    #
    # === Parameters
    # value(Float|Array|Hash):: Value(s) to be converted
    #
    # === Return
    # (String|Array|Hash):: Value(s) converted to decimal digit string
    def self.enough_precision(value)
      scale = [1.0, 10.0, 100.0, 1000.0, 10000.0, 100000.0]
      enough = lambda { |v| (v >= 10.0   ? 0 :
                            (v >= 1.0    ? 1 :
                            (v >= 0.1    ? 2 :
                            (v >= 0.01   ? 3 :
                            (v >  0.001  ? 4 :
                            (v >  0.0    ? 5 : 0)))))) }
      digit_str = lambda { |p, v| sprintf("%.#{p}f", (v * scale[p]).round / scale[p])}

      if value.is_a?(Float)
        digit_str.call(enough.call(value), value)
      elsif value.is_a?(Array)
        min, max = value.map { |_, v| enough.call(v) }.minmax
        precision = (max - min) > 1 ? min + 1 : max
        value.map { |k, v| [k, digit_str.call([precision, enough.call(v)].max, v)] }
      elsif value.is_a?(Hash)
        min, max = value.to_a.map { |_, v| enough.call(v) }.minmax
        precision = (max - min) > 1 ? min + 1 : max
        value.to_a.inject({}) { |s, v| s[v[0]] = digit_str.call([precision, enough.call(v[1])].max, v[1]); s }
      else
        value.to_s
      end
    end

    # Wrap string by breaking it into lines at the specified separator
    #
    # === Parameters
    # string(String):: String to be wrapped
    # max_length(Integer):: Maximum length of a line excluding indentation
    # indent(String):: Indentation for each line
    # separator(String):: Separator at which to make line breaks
    #
    # === Return
    # (String):: Multi-line string
    def self.wrap(string, max_length, indent, separator)
      all = []
      line = ""
      for l in string.split(separator)
        if (line + l).length >= max_length
          all.push(line)
          line = ""
        end
        line += line == "" ? l : separator + l
      end
      all.push(line).join(separator + "\n" + indent)
    end

    # Format UTC time value
    #
    # === Parameters
    # time(Integer):: Time in seconds in Unix-epoch to be formatted
    #
    # (String):: Formatted time string
    def self.time_at(time)
      Time.at(time).strftime("%a %b %d %H:%M:%S")
    end

    # Sort hash elements by key in ascending order into array of key/value pairs
    # Sort keys numerically if possible, otherwise as is
    #
    # === Parameters
    # hash(Hash):: Data to be sorted
    #
    # === Return
    # (Array):: Key/value pairs from hash in key sorted order
    def self.sort_key(hash)
      hash.to_a.map { |k, v| [k =~ /^\d+$/ ? k.to_i : k, v] }.sort
    end

    # Sort hash elements by value in ascending order into array of key/value pairs
    #
    # === Parameters
    # hash(Hash):: Data to be sorted
    #
    # === Return
    # (Array):: Key/value pairs from hash in value sorted order
    def self.sort_value(hash)
      hash.to_a.sort { |a, b| a[1] <=> b[1] }
    end

    # Converts server statistics to a displayable format
    #
    # === Parameters
    # stats(Hash):: Statistics with generic keys "name", "identity", "hostname", "service uptime",
    #   "machine uptime", "memory KB", "stat time", "last reset time", "version", and "broker" with
    #   the latter two and "machine uptime", "memory KB", "version", and "broker" being optional;
    #   any other keys ending with "stats" have an associated hash value that is displayed in sorted
    #   key order, unless "stats" is preceded by a non-blank, in which case that character is prepended
    #   to the key to drive the sort order
    # options(Hash):: Formatting options
    #   :name_width(Integer):: Maximum characters in displayed stat name
    #   :sub_name_width(Integer):: Maximum characters in displayed sub-stat name
    #   :sub_stat_value_width(Integer):: Maximum characters in displayed sub-stat value line
    #   :exception_message_width(Integer):: Maximum characters displayed for exception message
    #
    # === Return
    # (String):: Display string
    def self.stats_str(stats, options = {})
      name_width = options[:name_width] || MAX_STAT_NAME_WIDTH

      str = stats["name"] ? sprintf("%-#{name_width}s#{SEPARATOR}%s\n", "name", stats["name"]) : ""
      str += sprintf("%-#{name_width}s#{SEPARATOR}%s\n", "identity", stats["identity"]) +
             sprintf("%-#{name_width}s#{SEPARATOR}%s\n", "hostname", stats["hostname"]) +
             sprintf("%-#{name_width}s#{SEPARATOR}%s\n", "stat time", time_at(stats["stat time"])) +
             sprintf("%-#{name_width}s#{SEPARATOR}%s\n", "last reset", time_at(stats["last reset time"])) +
             sprintf("%-#{name_width}s#{SEPARATOR}%s\n", "service up", elapsed(stats["service uptime"]))
      if stats.has_key?("machine uptime")
        str += sprintf("%-#{name_width}s#{SEPARATOR}%s\n", "machine up", elapsed(stats["machine uptime"]))
      end
      if stats.has_key?("memory")
        str += sprintf("%-#{name_width}s#{SEPARATOR}%s\n", "memory KB", stats["memory"])
      end
      if stats.has_key?("version")
        str += sprintf("%-#{name_width}s#{SEPARATOR}%s\n", "version", stats["version"].to_i)
      end
      if stats.has_key?("brokers")
         str += brokers_str(stats["brokers"], options)
      end
      stats.to_a.sort_by { |(k, v)| k.to_s =~ /(.)stats$/ ? ($1 == ' ' ? '~' : $1) + k : k }.each do |k, v|
        str += sub_stats_str(k[0..-7], v, options) if k.to_s =~ /stats$/
      end
      str
    end

    # Convert broker information to displayable format
    #
    # === Parameter
    # brokers(Hash):: Broker stats with keys
    #   "brokers"(Array):: Stats for each broker in priority order as hash with keys
    #     "alias"(String):: Broker alias
    #     "identity"(String):: Broker identity
    #     "status"(Symbol):: Status of connection
    #     "disconnect last"(Hash|nil):: Last disconnect information with key "elapsed", or nil if none
    #     "disconnects"(Integer|nil):: Number of times lost connection, or nil if none
    #     "failure last"(Hash|nil):: Last connect failure information with key "elapsed", or nil if none
    #     "failures"(Integer|nil):: Number of failed attempts to connect to broker, or nil if none
    #     "retries"(Integer|nil):: Number of attempts to connect after failure, or nil if none
    #   "exceptions"(Hash|nil):: Exceptions raised per category, or nil if none
    #     "total"(Integer):: Total exceptions for this category
    #     "recent"(Array):: Most recent as a hash of "count", "type", "message", "when", and "where"
    #   "heartbeat"(Integer|nil):: Number of seconds between AMQP heartbeats, or nil if heartbeat disabled
    #   "returns"(Hash|nil):: Message return activity stats with keys "total", "percent", "last", and "rate"
    #     with percentage breakdown per request type, or nil if none
    # options(Hash):: Formatting options
    #   :name_width(Integer):: Fixed width for left-justified name display
    #   :sub_name_width(Integer):: Maximum characters in displayed sub-stat name
    #   :sub_stat_value_width(Integer):: Maximum characters in displayed sub-stat value line
    #   :exception_message_width(Integer):: Maximum characters displayed for exception message
    #
    # === Return
    # str(String):: Broker display with one line per broker plus exceptions
    def self.brokers_str(brokers, options = {})
      name_width = options[:name_width] || MAX_STAT_NAME_WIDTH
      sub_name_width = options[:sub_name_width] || MAX_SUB_STAT_NAME_WIDTH
      sub_stat_value_width = options[:sub_stat_value_width] || MAX_SUB_STAT_VALUE_WIDTH

      value_indent = " " * (name_width + SEPARATOR.size)
      sub_value_indent = " " * (name_width + sub_name_width + (SEPARATOR.size * 2))
      str = sprintf("%-#{name_width}s#{SEPARATOR}", "brokers")
      brokers["brokers"].each do |b|
        disconnects = if b["disconnects"]
          "#{b["disconnects"]} (#{elapsed(b["disconnect last"]["elapsed"])} ago)"
        else
          "none"
        end
        failures = if b["failures"]
          retries = b["retries"]
          retries = " w/ #{retries} #{retries != 1 ? 'retries' : 'retry'}" if retries
          "#{b["failures"]} (#{elapsed(b["failure last"]["elapsed"])} ago#{retries})"
        else
          "none"
        end
        str += "#{b["alias"]}: #{b["identity"]} #{b["status"]}, disconnects: #{disconnects}, failures: #{failures}\n"
        str += value_indent
      end
      str += sprintf("%-#{sub_name_width}s#{SEPARATOR}", "exceptions")
      str += if brokers["exceptions"].nil? || brokers["exceptions"].empty?
        "none\n"
      else
        exceptions_str(brokers["exceptions"], sub_value_indent, options) + "\n"
      end
      str += value_indent
      str += sprintf("%-#{sub_name_width}s#{SEPARATOR}", "heartbeat")
      str += if [nil, 0].include?(brokers["heartbeat"])
        "none\n"
      else
        "#{brokers["heartbeat"]} sec\n"
      end
      str += value_indent
      str += sprintf("%-#{sub_name_width}s#{SEPARATOR}", "returns")
      str += if brokers["returns"].nil? || brokers["returns"].empty?
        "none\n"
      else
        wrap(activity_str(brokers["returns"]), sub_stat_value_width, sub_value_indent, ", ") + "\n"
      end
    end

    # Convert grouped set of statistics to displayable format
    # Provide special formatting for stats named "exceptions"
    # Break out percentages and total count for stats containing "percent" hash value
    # sorted in descending percent order and followed by total count
    # Convert to elapsed time for stats with name ending in "last"
    # Add "/sec" to values with name ending in "rate"
    # Add " sec" to values with name ending in "time"
    # Add "%" to values with name ending in "percent" and drop "percent" from name
    # Use elapsed time formatting for values with name ending in "age"
    # Display any nil value, empty hash, or hash with a "total" value of 0 as "none"
    # Display any floating point value or hash of values with at least two significant digits of precision
    #
    # === Parameters
    # name(String):: Display name for the stat
    # value(Object):: Value of this stat
    # options(Hash):: Formatting options
    #   :name_width(Integer):: Fixed width for left-justified name display
    #   :sub_name_width(Integer):: Maximum characters in displayed sub-stat name
    #   :sub_stat_value_width(Integer):: Maximum characters in displayed sub-stat value line
    #   :exception_message_width(Integer):: Maximum characters displayed for exception message
    #
    # === Return
    # (String):: Single line display of stat
    def self.sub_stats_str(name, value, options = {})
      name_width = options[:name_width] || MAX_STAT_NAME_WIDTH
      sub_name_width = options[:sub_name_width] || MAX_SUB_STAT_NAME_WIDTH
      sub_stat_value_width = options[:sub_stat_value_width] || MAX_SUB_STAT_VALUE_WIDTH

      value_indent = " " * (name_width + SEPARATOR.size)
      sub_value_indent = " " * (name_width + sub_name_width + (SEPARATOR.size * 2))
      sprintf("%-#{name_width}s#{SEPARATOR}", name) + value.to_a.sort.map do |attr|
        k, v = attr
        name = k =~ /percent$/ ? k[0..-9] : k
        sprintf("%-#{sub_name_width}s#{SEPARATOR}", name) + if v.is_a?(Float) || v.is_a?(Integer)
          str = k =~ /age$/ ? elapsed(v) : enough_precision(v)
          str += "/sec" if k =~ /rate$/
          str += " sec" if k =~ /time$/
          str += "%" if k =~ /percent$/
          str
        elsif v.is_a?(Hash)
          if v.empty? || v["total"] == 0
            "none"
          elsif v["total"]
            wrap(activity_str(v), sub_stat_value_width, sub_value_indent, ", ")
          elsif k =~ /last$/
            last_activity_str(v)
          elsif k == "exceptions"
            exceptions_str(v, sub_value_indent, options)
          else
            wrap(hash_str(v), sub_stat_value_width, sub_value_indent, ", ")
          end
        else
          "#{v || "none"}"
        end + "\n"
      end.join(value_indent)
    end

    # Convert activity information to displayable format
    #
    # === Parameters
    # value(Hash|nil):: Information about activity, or nil if the total is 0
    #   "total"(Integer):: Total activity count
    #   "percent"(Hash):: Percentage for each type of activity if tracking type, otherwise omitted
    #   "last"(Hash):: Information about last activity
    #     "elapsed"(Integer):: Seconds since last activity started
    #     "type"(String):: Type of activity if tracking type, otherwise omitted
    #     "active"(Boolean):: Whether activity still active if tracking whether active, otherwise omitted
    #   "rate"(Float):: Recent average rate if measuring rate, otherwise omitted
    #   "duration"(Float):: Average duration of activity if tracking duration, otherwise omitted
    #
    # === Return
    # str(String):: Activity stats in displayable format without any line separators
    def self.activity_str(value)
      str = ""
      str += enough_precision(sort_value(value["percent"]).reverse).map { |k, v| "#{k}: #{v}%" }.join(", ") +
             ", total: " if value["percent"]
      str += "#{value['total']}"
      str += ", last: #{last_activity_str(value['last'], single_item = true)}" if value["last"]
      str += ", rate: #{enough_precision(value['rate'])}/sec" if value["rate"]
      str += ", duration: #{enough_precision(value['duration'])} sec" if value["duration"]
      value.each do |name, data|
        unless ["total", "percent", "last", "rate", "duration"].include?(name)
          str += ", #{name}: #{data.is_a?(String) ? data : data.inspect}"
        end
      end
      str
    end
 
    # Convert last activity information to displayable format
    #
    # === Parameters
    # last(Hash):: Information about last activity
    #   "elapsed"(Integer):: Seconds since last activity started
    #   "type"(String):: Type of activity if tracking type, otherwise omitted
    #   "active"(Boolean):: Whether activity still active if tracking whether active, otherwise omitted
    # single_item:: Whether this is to appear as a single item in a comma-separated list
    #   in which case there should be no ':' in the formatted string
    #
    # === Return
    # str(String):: Last activity in displayable format without any line separators
    def self.last_activity_str(last, single_item = false)
      str = "#{elapsed(last['elapsed'])} ago"
      str += " and still active" if last["active"]
      if last["type"]
        if single_item
          str = "#{last['type']} (#{str})"
        else
          str = "#{last['type']}: #{str}"
        end
      end
      str
    end

    # Convert exception information to displayable format
    #
    # === Parameters
    # exceptions(Hash):: Exceptions raised per category
    #   "total"(Integer):: Total exceptions for this category
    #   "recent"(Array):: Most recent as a hash of "count", "type", "message", "when", and "where"
    # indent(String):: Indentation for each line
    # options(Hash):: Formatting options
    #   :exception_message_width(Integer):: Maximum characters displayed for exception message
    #
    # === Return
    # (String):: Exceptions in displayable format with line separators
    def self.exceptions_str(exceptions, indent, options = {})
      exception_message_width = options[:exception_message_width] || MAX_EXCEPTION_MESSAGE_WIDTH
      indent2 = indent + (" " * 4)
      exceptions.to_a.sort.map do |k, v|
        sprintf("%s total: %d, most recent:\n", k, v["total"]) + v["recent"].reverse.map do |e|
          message = e["message"]
          if message && message.size > (exception_message_width - 3)
            message = e["message"][0, exception_message_width - 3] + "..."
          end
          indent + "(#{e["count"]}) #{time_at(e["when"])} #{e["type"]}: #{message}\n" + indent2 + "#{e["where"]}"
        end.join("\n")
      end.join("\n" + indent)
    end

    # Convert arbitrary nested hash to displayable format
    # Sort hash by key, numerically if possible, otherwise as is
    # Display any floating point values with one decimal place precision
    # Display any empty values as "none"
    #
    # === Parameters
    # hash(Hash):: Hash to be displayed
    #
    # === Return
    # (String):: Single line hash display
    def self.hash_str(hash)
      str = ""
      sort_key(hash).map do |k, v|
        "#{k}: " + if v.is_a?(Float)
          enough_precision(v)
        elsif v.is_a?(Hash)
          "[ " + hash_str(v) + " ]"
        else
          "#{v || "none"}"
        end
      end.join(", ")
    end

  end # Stats

end # RightSupport
