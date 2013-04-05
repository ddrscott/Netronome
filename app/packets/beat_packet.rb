class BeatPacket

  attr_accessor :time_ms, :bpm

  def initialize(time_ms, bpm)
    @time_ms, @bpm = time_ms, bpm
  end

  def self.parse(data)
    _, a, b = *(data.split '|')
    BeatPacket.new(a.to_i, b.to_i)
  end

  def to_s
    "bp|#{self.time_ms}|#{self.bpm}"
  end
end