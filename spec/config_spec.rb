require 'spec_helper'

describe LionAttr do
  it 'can be configured via #configuree by passing a block' do
    LionAttr.configure do |config|
      config.redis_config = { :a => 1 }
    end

    expect(LionAttr::Config.redis_config[:a]).to eq 1
  end

  describe "#configure" do
    it 'returns config object' do
      expect(LionAttr.configure).to be LionAttr::Config
    end
  end
end
