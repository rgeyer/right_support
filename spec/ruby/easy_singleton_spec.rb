require 'spec_helper'

class Alice
  include Singleton
  include RightSupport::Ruby::EasySingleton

  def alice?
    true
  end
end

class Bob
  include RightSupport::Ruby::EasySingleton

  def bob?
    true
  end
end

describe RightSupport::Ruby::EasySingleton do
  context 'when mixed into a base class' do
    it 'ensures the base is already a Singleton' do
      Alice.ancestors.should include(Singleton)
      Bob.ancestors.should include(Singleton)
    end

    it 'adds a class-level method_missing' do
      Alice.alice?.should be_true
      Bob.bob?.should be_true

      lambda { Alice.bob? }.should raise_error(NoMethodError)
    end

    it 'modifies class-level respond_to? to be truthful' do
      Alice.respond_to?(:alice?).should be_true
      Bob.respond_to?(:bob?).should be_true
      Alice.respond_to?(:bob?).should be_false
      Bob.respond_to?(:alice?).should be_false
    end
  end
end