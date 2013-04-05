class Time
  def self.now_ms
    (now.to_f * 1000).round
  end
end