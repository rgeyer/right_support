require 'spec_helper'

describe RightSupport::Data::UUID do
  subject { RightSupport::Data::UUID }

  VALID_UUID = /[0-9a-f-]+/ #we're not too picky here...

  context :generate do
    context 'when no implementation is available' do
      it 'raises Unavailable' do
        flexmock(subject).should_receive(:implementation).and_return(nil)
        lambda {
          subject.generate
        }.should raise_error(subject::Unavailable)
      end
    end

    context 'when SimpleUUID is available' do
      it 'generates UUIDs' do
        subject.implementation = subject::SimpleUUID
        subject.generate.should =~ VALID_UUID
      end
    end

    context 'when UUIDTools v1 is available' do
      it 'generates UUIDs' do
        pending #need to rework tests to test 2 versions of 1 gem!
      end
    end

    context 'when UUIDTools v2 is available' do
      it 'generates UUIDs' do
        subject.implementation = subject::UUIDTools2
        subject.generate.should =~ VALID_UUID
      end
    end

    context 'when UUID gem is available' do
      it 'generates UUIDs' do
        subject.implementation = subject::UUIDGem
        subject.generate.should =~ VALID_UUID
      end
    end
  end
end
