require 'spec_helper'

module RightSupport::Data::HashToolsSpec

  class BetterHash < Hash
    def bells_and_whistles; true; end
  end

  class HashLike
    def initialize; @inner_hash = {}; end
    def has_key?(key); @inner_hash.has_key?(key); end
    def [](key); @inner_hash[key]; end
    def []=(key, value); @inner_hash[key] = value; end
    def delete(key); @inner_hash.delete(key); end
    def merge!(other); @inner_hash.merge!(other); self; end
    def ==(other); @inner_hash == other; end
  end

  class DuplicableValue
    def initialize(value); @value = value; end
    attr_accessor :value
    def duplicable?; true; end
    def ==(other); other.kind_of?(DuplicableValue) && value == other.value; end
  end

end

describe RightSupport::Data::HashTools do
  subject { RightSupport::Data::HashTools }

  context '#hashable?' do
    it 'should be true for hashes' do
      subject.hashable?({}).should be_true
    end

    it 'should be true for hash-based objects' do
      subject.hashable?(::RightSupport::Data::HashToolsSpec::BetterHash.new).should be_true
    end

    it 'should be true for hash-like objects' do
      subject.hashable?(::RightSupport::Data::HashToolsSpec::HashLike.new).should be_true
    end

    it 'should be false for unhashable objects' do
      subject.hashable?([1, 2, 3]).should be_false
      subject.hashable?("hi there").should be_false
    end
  end

  context '#hash_like?' do
    it 'should be true for Hash' do
      subject.hash_like?(::Hash).should be_true
    end

    it 'should be true for hash-based classes' do
      subject.hash_like?(::RightSupport::Data::HashToolsSpec::BetterHash).should be_true
    end

    it 'should be true for hash-like classes' do
      subject.hash_like?(::RightSupport::Data::HashToolsSpec::HashLike).should be_true
    end

    it 'should be false for non-hash classes' do
      subject.hash_like?(Array).should be_false
      subject.hash_like?(String).should be_false
    end
  end

  context '#deep_get' do
    hash = { 'tree' => { 'branch' => { 'leaf' => 42, 'other' => 41 },
                         'other' => { 'leaf' => 43 } } }
    {
      :valid_leaf => {
        :path => ['tree', 'branch', 'leaf'],
        :expected => 42 },
      :valid_other_leaf => {
        :path => ['tree', 'branch', 'other'],
        :expected => 41 },
      :valid_branch => {
        :path => ['tree', 'branch'],
        :expected => { 'leaf' => 42, 'other' => 41 } },
      :valid_other_branch => {
        :path => ['tree', 'other'],
        :expected => { 'leaf' => 43 } },
      :invalid_leaf => {
        :path => ['tree', 'branch', 'leaf', 'bogus'],
        :expected => nil },
      :invalid_branch => {
        :path => ['tree', 'bogus'],
        :expected => nil },
      :nil => {
        :path => nil,
        :expected => nil },
      :empty => {
        :path => [],
        :expected => nil }
    }.each do |kind, data|
      it "should deep get #{kind} paths" do
        actual = subject.deep_get(hash, data[:path])
        actual.should == data[:expected]
      end
    end
  end

  context '#deep_set!' do
    {
      :empty => {
        :target => {},
        :path => ['tree', 'branch', 'leaf'],
        :value => 42,
        :expected => { 'tree' => { 'branch' => { 'leaf' => 42 } } } },
      :identical_structure => {
        :target => { 'tree' => { 'branch' => { 'leaf' => 42 } } },
        :path => ['tree', 'branch', 'leaf'],
        :value => 41,
        :expected => { 'tree' => { 'branch' => { 'leaf' => 41 } } } },
      :similar_structure => {
        :target => { 'tree' => { 'branch' => { 'other' => 41 } } },
        :path => ['tree', 'branch', 'leaf'],
        :value => 42,
        :expected => { 'tree' => { 'branch' => { 'leaf' => 42, 'other' => 41 } } } },
      :different_hash_subclass => {
        :target => {},
        :path => ['tree', 'branch', 'leaf'],
        :value => 42,
        :clazz => ::RightSupport::Data::HashToolsSpec::BetterHash,
        :expected => { 'tree' => { 'branch' => { 'leaf' => 42 } } } },
      :different_hash_like_class => {
        :target => {},
        :path => ['tree', 'branch', 'leaf'],
        :value => 42,
        :clazz => ::RightSupport::Data::HashToolsSpec::HashLike,
        :expected => { 'tree' => { 'branch' => { 'leaf' => 42 } } } }
    }.each do |kind, data|
      it "should deep set values in #{kind} hashes" do
        subject.deep_set!(data[:target], data[:path], data[:value], data[:clazz])
        data[:target].should == data[:expected]
        expected_class = data[:clazz] || data[:target].class
        data[:target].values.first.class.should == expected_class
      end
    end
  end

  context '#deep_clone' do
    def deep_check_object_id(a, b)
      a.object_id.should_not == b.object_id
      a.each do |k, v|
        if subject.hashable?(v)
          deep_check_object_id(v, b[k])
        elsif v.respond_to?(:duplicable?) && v.duplicable?
          v.object_id.should_not == b[k].object_id
        else
          v.object_id.should == b[k].object_id
        end
      end
    end

    {
      :empty => {},
      :shallow => { :x => 1, :y => 2 },
      :deep => { :x => 1, :y => { :a => 'A' }, :z => { :b => 'B', :c => { :foo => :bar }} },
      :duplicable => {
        :tree => {
          :branch => {
            :a => ::RightSupport::Data::HashToolsSpec::DuplicableValue.new(1),
            :b => ::RightSupport::Data::HashToolsSpec::DuplicableValue.new('hi there') } } }
    }.each do |kind, data|
      it "should deep clone values in #{kind} hashes" do
        actual = subject.deep_clone(data)
        actual.should == data
        if :duplicable == kind
          # verify that leaves are duplicable
          data[:tree][:branch][:a].duplicable?.should be_true
          data[:tree][:branch][:b].duplicable?.should be_true
        end
        deep_check_object_id(actual, data)
      end
    end
  end

  context '#deep_merge!' do
    {
      :identical => {
        :left     => { :one => 1 },
        :right    => { :one => 1 },
        :expected => { :one => 1 } },
      :disjoint => {
        :left     => { :one => 1 },
        :right    => { :two => 1 },
        :expected => { :one => 1, :two => 1 } },
      :value_diff => {
        :left     => { :one => 1 },
        :right    => { :one => 2 },
        :expected => { :one => 2 } },
      :recursive_disjoint => {
        :left     => { :one => { :a => 1, :b => 2 }, :two => 3 },
        :right    => { :one => { :a => 1 }, :two => 3 },
        :expected => { :one => { :a => 1, :b => 2 }, :two => 3 } },
      :recursive_value_diff => {
        :left     => { :one => { :a => 1, :b => 2 }, :two => 3 },
        :right    => { :one => { :a => 1, :b => 3 }, :two => 3 },
        :expected => { :one => { :a => 1, :b => 3 }, :two => 3 } },
      :recursive_disjoint_and_value_diff => {
        :left     => { :one => { :a => 1, :b => 2, :c => 3 }, :two => 3, :three => 4 },
        :right    => { :one => { :a => 1, :b => 3, :d => 4 }, :two => 5, :four => 6 },
        :expected => { :one => { :a => 1, :b => 3, :c => 3 , :d => 4 }, :two => 5, :three => 4, :four => 6 } }
    }.each do |kind, data|
      it "should deep merge #{kind} hashes" do
        actual = subject.deep_merge!(data[:left], data[:right])
        actual.should == data[:expected]
      end
    end
  end

  context "#deep_remove!" do
    {
      :empty => {
        :target   => {},
        :source   => {},
        :expected => {} },
      :identical => {       clazz
        :target   => { :x => 1, :y => { :foo => :bar } },
        :source   => { :x => 1, :y => { :foo => :bar } },
        :expected => {} },
      :greater_target => {
        :target   => { :x => 1, :y => { :a => 'a', :b => 'b' } },
        :source   => { :x => 1, :y => { :a => 'a' } },
        :expected => { :y => { :b => 'b' } } },
      :greater_source => {
        :target   => { :x => 1, :y => { :a => 'a' } },
        :source   => { :x => 1, :y => { :a => 'a', :b => 'b' } },
        :expected => { :y => {} } },
      :disjoint => {
        :target   => { :x => 1, :y => { :a => 'a' } },
        :source   => { :x => 2, :y => { :b => 'b' } },
        :expected => { :x => 1, :y => { :a => 'a' } } }
    }.each do |kind, data|
      it "should deep remove values from #{kind} hashes" do
        actual = subject.deep_remove!(data[:target], data[:source])
        actual.should == data[:expected]
      end
    end
  end

  context "#deep_create_patch" do
    {
      :identical => {
        :left     => { :one => 1 },
        :right    => { :one => 1 },
        :expected => { :left_only  => {},
                       :right_only => {},
                       :diff       => {} } },
      :disjoint => {
        :left     => { :one => 1 },
        :right    => { :two => 1 },
        :expected => { :left_only  => { :one => 1},
                       :right_only => { :two => 1},
                       :diff       => {} }
        },
      :value_diff => {
        :left     => { :one => 1 },
        :right    => { :one => 2 },
        :expected => { :left_only  => {},
                       :right_only => {},
                       :diff       => { :one => { :left => 1, :right => 2} } } },
      :recursive_disjoint => {
        :left     => { :one => { :a => 1, :b => 2 }, :two => 3 },
        :right    => { :one => { :a => 1 }, :two => 3 },
        :expected => { :left_only  => { :one => { :b => 2 }},
                       :right_only => {},
                       :diff       => {} } },
      :recursive_value_diff => {
        :left     => { :one => { :a => 1, :b => 2 }, :two => 3 },
        :right    => { :one => { :a => 1, :b => 3 }, :two => 3 },
        :expected => { :left_only  => {},
                       :right_only => {},
                       :diff       => { :one => { :b => { :left => 2, :right => 3 }} } } },
      :recursive_disjoint_and_value_diff => {
        :left     => { :one => { :a => 1, :b => 2, :c => 3 }, :two => 3, :three => 4 },
        :right    => { :one => { :a => 1, :b => 3, :d => 4 }, :two => 5, :four => 6 },
        :expected => { :left_only  => { :one => { :c => 3 }, :three => 4 },
                       :right_only => { :one => { :d => 4 }, :four => 6 },
                       :diff       => { :one => { :b => { :left => 2, :right => 3 }}, :two => { :left => 3, :right => 5 } } } }
    }.each do |kind, data|
      it "should deep create patch for #{kind} hashes" do
        actual = subject.deep_create_patch(data[:left], data[:right])
        actual.should == data[:expected]
      end
    end
  end

  context '#deep_apply_patch!' do
    {
      :empty_patch => {
        :target   => { :one => 1 },
        :patch    => { :left_only => {}, :right_only => {}, :diff => {} },
        :expected => { :one => 1 } },
      :disjoint => {
        :target   => { :one => 1 },
        :patch    => { :left_only => { :one => 2 }, :right_only => {}, :diff => { :one => { :left => 3, :right => 4 } } },
        :expected => { :one => 1 } },
      :removal => {
        :target   => { :one => 1 },
        :patch    => { :left_only => { :one => 1 }, :right_only => {}, :diff => {} },
        :expected => {} },
      :addition => {
        :target   => { :one => 1 },
        :patch    => { :left_only => {}, :right_only => { :two => 2 }, :diff => {} },
        :expected => { :one => 1, :two => 2 } },
      :substitution => {
        :target   => { :one => 1 },
        :patch    => { :left_only => {}, :right_only => {}, :diff => { :one => { :left => 1, :right => 2 } } },
        :expected => { :one => 2 } },
      :recursive_removal => {
        :target   => { :one => { :a => 1, :b => 2 } },
        :patch    => { :left_only => { :one => { :a => 1 }}, :right_only => {}, :diff => {} },
        :expected => { :one => { :b => 2 } } },
      :recursive_addition => {
        :target   => { :one => { :a => 1 } },
        :patch    => { :left_only => {}, :right_only => { :one => { :b => 2 } }, :diff => {} },
        :expected => { :one => { :a => 1, :b => 2 } } },
      :recursive_substitution => {
        :target   => { :one => { :a => 1 } },
        :patch    => { :left_only => {}, :right_only => {}, :diff => { :one => { :a => { :left => 1, :right => 2 } } } },
        :expected => { :one => { :a => 2 } } },
      :combined => {
        :target   => { :one => { :a => 1, :b => 2 } },
        :patch    => { :left_only => { :one => { :a => 1 } }, :right_only => { :one => { :c => 3 }}, :diff => { :one => { :b => { :left => 2, :right => 3 } } } },
        :expected => { :one => { :b => 3, :c => 3 } } }
    }.each do |kind, data|
      it "should deep apply #{kind} patches" do
        actual = subject.deep_apply_patch!(data[:target], data[:patch])
        actual.should == data[:expected]
      end
    end
  end
end
