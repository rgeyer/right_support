# Copyright (c) 2009-2011 RightScale, Inc, All Rights Reserved Worldwide.
#
# THIS PROGRAM IS CONFIDENTIAL AND PROPRIETARY TO RIGHTSCALE
# AND CONSTITUTES A VALUABLE TRADE SECRET.  Any unauthorized use,
# reproduction, modification, or disclosure of this program is
# strictly prohibited.  Any use of this program by an authorized
# licensee is strictly subject to the terms and conditions,
# including confidentiality obligations, set forth in the applicable
# License Agreement between RightScale.com, Inc. and the licensee.

require 'right_support/net/ssl/open_ssl_patch'

module RightSupport::Net
  module SSL
    module_function

    def expected_hostname
      @expected_hostname
    end

    def with_expected_hostname(hostname, &block)
      @expected_hostname = hostname
      block.call
    rescue Exception => e
      @expected_hostname = nil
      raise e
    ensure
      @expected_hostname = nil
    end
  end
end

RightSupport::Net::SSL::OpenSSLPatch.enable!
