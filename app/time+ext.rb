class Time
  def self.now_ms
    (now.to_f * 1000).round
  end

  # For some reason, exact time is not as accurate :/
  #   exact_time = now.to_f
  #   seconds = (exact_time - exact_time.to_i)
  def self.till_next_second
    1.0 - ((now_ms % 1000) / 1000)
  end
end