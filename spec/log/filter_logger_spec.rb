require 'spec_helper'

describe RightSupport::Log::FilterLogger do
  it 'does method_missing correctly'
  it 'does respond_to? correctly'
  it 'transparently proxies Logger methods to underlying object'
  it 'filters log messages'
end