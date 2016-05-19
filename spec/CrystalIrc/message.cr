def cli
  CrystalIrc::Client.new nick: "a", ip: "localhost"
end

describe CrystalIrc::Message do

  it "Basics instance" do
    m = CrystalIrc::Message.new(":source CMD arg1 arg2 :message", cli)
    m.source.should eq("source")
    m.command.should eq("CMD")
    m.arguments.should eq("arg1 arg2")
    m.message.should eq("message")
  end

  it "Instance with no message" do
    m = CrystalIrc::Message.new(":source CMD arg1 arg2", cli)
    m.source.should eq("source")
    m.command.should eq("CMD")
    m.arguments.should eq("arg1 arg2")
  end

  it "Instance wit no arguments" do
    m = CrystalIrc::Message.new(":source CMD :message", cli)
    m.source.should eq("source")
    m.command.should eq("CMD")
    m.message.should eq("message")
  end

  it "Instance with no source" do
    m = CrystalIrc::Message.new("CMD arg1 arg2 :message", cli)
    m.source.should eq(nil)
    m.command.should eq("CMD")
    m.arguments.should eq("arg1 arg2")
    m.message.should eq("message")
  end

end