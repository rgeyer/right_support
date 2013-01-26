# Workaround for badly-coded gems such as active_support which fail to require this for themselves
require 'thread'

require 'right_support/ruby'

module RightSupport
  autoload :Log, 'right_support/log'
  autoload :Data, 'right_support/data'
  autoload :Validation, 'right_support/validation'
  autoload :Crypto, 'right_support/crypto'
  autoload :Rack, 'right_support/rack'
  autoload :DB, 'right_support/db'
  autoload :Net, 'right_support/net'
  autoload :Config, 'right_support/config'
  autoload :Stats, 'right_support/stats'
  autoload :CI, 'right_support/ci'
end
