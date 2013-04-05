class TimingPacket

  attr_reader :time_ms, :interval

  attr_accessor :latency, :received_ms

  def initialize(time_ms, interval)
    @time_ms, @interval = time_ms, interval
  end

  def self.parse(data)
    _, a, b = *data.split('|')
    TimingPacket.new(a.to_i, b.to_i)
  end

  def to_s
    "tm|#{self.time_ms}|#{self.interval}"
  end
end