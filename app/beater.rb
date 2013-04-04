class Beater

  attr_reader :bpm, :sec_per_beat, :total_beats

  def initialize(delegate)
    @delegate = delegate

    @total_beats = 0
  end

  def start(bpm)
    @bpm = bpm
    @sec_per_beat = 60.0 / bpm

    @started ||= begin
      logger.debug{"add_periodic_timer: @ms_per_beat => #{@sec_per_beat}"}
      @timer = EM.add_periodic_timer(@sec_per_beat) do
        Dispatch::Queue.main.async do
          @delegate.on_beat(@bpm, @total_beats)
        end
        @total_beats += 1
      end
      true
    end
  end

  def stop
    EM.cancel_timer(@timer) if @timer

    @started = false
  end
end