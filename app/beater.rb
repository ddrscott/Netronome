class Beater

  attr_reader :bpm, :sec_per_beat, :total_beats, :start_time_ms

  def initialize(delegate)
    @delegate = delegate

    @total_beats = 0
  end

  def start(bpm, offset_ms=0)
    @bpm = bpm
    @sec_per_beat = 60.0 / bpm

    @ms_per_beat = (@sec_per_beat * 1000).round

    @started ||= begin

      delay = ((Time.now_ms + offset_ms) % @ms_per_beat).to_f / 1000
      logger.debug{"waiting #{delay} seconds to start on the beat"}
      @delay_timer = EM.add_timer(delay) do
        logger.debug{"add_periodic_timer: @sec_per_beat => #{@sec_per_beat}"}
        @start_time_ms = (Time.now.to_f * 1000).round
        @timer = EM.add_periodic_timer(@sec_per_beat) do
          Dispatch::Queue.main.async do
            @delegate.on_beat(self)
          end
          @total_beats += 1
        end
        # handle first beat
        @delegate.on_beat(self)
      end

      true
    end
  end

  def stop
    logger.debug{'stopping beater'}
    EM.cancel_timer(@delay_timer) if @delay_timer
    EM.cancel_timer(@timer) if @timer

    @started = nil
  end
end