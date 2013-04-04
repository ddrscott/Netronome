class BeatPacket

  attr_accessor :bpm, :beat, :interval

  def self.parse(data)
    beat = BeatPacket.new
    beat.bpm, beat.beat, beat.interval = *data.split('|')
    beat
  end

  def to_s
    "#{self.bpm}|#{self.beat}|#{self.interval}"
  end
end