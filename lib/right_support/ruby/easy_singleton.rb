require 'singleton'

module RightSupport::Ruby
  module EasySingleton
    module ClassMethods
      def method_missing(meth, *args)
        if self.instance && self.instance.respond_to?(meth)
          self.instance.__send__(meth, *args)
        else
          super
        end
      end

      def respond_to?(meth)
        super(meth) || self.instance.respond_to?(meth)
      end
    end

    def self.included(base)
      base.__send__(:include, ::Singleton) unless base.ancestors.include?(::Singleton)
      base.__send__(:extend, ClassMethods)
    end
  end
end