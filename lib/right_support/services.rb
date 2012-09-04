module RightSupport
  module Services
    class UnknownService < Exception; end
    class MissingConfiguration < Exception; end
    class BadProxy < Exception; end

    CLASS_CONFIG_KEY    = 'class'
    SETTINGS_CONFIG_KEY = 'settings'

    #Map of service_name => service_object
    @services = {}
    #Map of service_name => service_info [who defines that service]
    @service_infos = {}

    #TODO docs
    def self.register(info)
      info.each_pair { |name, _| @service_infos[name] = info }
    end

    #TODO docs
    def self.reset
      @services = {}
      @service_infos = {}
    end

    # TODO docs
    def self.respond_to?(name)
      name = name.to_s
       @service_infos.key?(name)
    end

    #TODO docs
    def self.method_missing(name, *params)
      unless params.empty?
        # If someone passed params, they don't mean to locate a service proxy object; punt to our superclass.
        super
      end

      name = name.to_s
      info = @service_infos[name]
      raise UnknownService, "The #{name} service has not been registered" unless info

      #Clear the cache when ANY ServiceInfo changes. Brutal but simple...
      @services = {} if info.freshen

      service = @services[name]

      #Instantiate the service proxy object if needed
      unless service
        service_stanza = info[name]
        proxy_klass = service_stanza[CLASS_CONFIG_KEY].to_const
        raise MissingConfiguration, "Every service must have a 'class' setting" unless proxy_klass
        begin
          service = proxy_klass.new(service_stanza[SETTINGS_CONFIG_KEY])
        rescue ArgumentError => e
          raise BadProxy,
                'ArgumentError while calling service proxy initializer; ' +
                'please make sure it accepts one parameter: a settings hash'
        end

      @services[name] = service
      end

      return service
    end
  end
end

Dir[File.expand_path('../services/*.rb', __FILE__)].each do |filename|
  require filename
end
