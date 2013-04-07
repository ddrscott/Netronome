class Time
  def self.now_ms
    (now.to_f * 1000).round
  end

  def self.till_next_second
    exact_time = now.to_f
    1.0 - (exact_time - exact_time.to_i)
  end
end