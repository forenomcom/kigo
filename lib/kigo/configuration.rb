module Kigo
  class Configuration
    attr_accessor :username, :password, :concurrency, :rate_limit_timeout

    def initialize opts = {}
      @rate_limit_timeout = 5
      @concurrency        = 4
    end
  end

  class << self
    attr_accessor :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end