class Time
  def self.now_ms
    (now.to_f * 1000).round
  end

  def self.till_next_second
    exact_time = now.to_f
    seconds = (exact_time - exact_time.to_i)
    1.0 - seconds
  end
end