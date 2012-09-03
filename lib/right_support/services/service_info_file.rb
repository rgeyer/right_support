module RightSupport::Services
  class ServiceInfoFile < ServiceInfo
    #TODO docs
    def initialize(filename)
      super
      @filename = filename
      freshen
    end

    #TODO docs
    def freshen
      mtime = File.stat(@filename).mtime
      last_mtime = @last_mtime
      @last_mtime = mtime
      return false if last_mtime && mtime <= last_mtime
      content = File.read(@filename)
      @services = YAML.load(content)
      return true
    end
  end
end