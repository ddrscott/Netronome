class Beater
  include DispatchHelper

  attr_reader :bpm, :sec_per_beat, :total_beats, :start_time

  def initialize(delegate)
    @delegate = delegate

    @total_beats = 0
  end

  def start(bpm, offset=nil)
    @bpm = bpm
    @sec_per_beat = 60.0 / bpm

    @ms_per_beat = (@sec_per_beat * 1000).round

    @started ||= begin
      @beat_timer = EM.add_timer(offset || Time.till_next_second) do
        logger.debug{"add_periodic_timer: @sec_per_beat => #{@sec_per_beat}"}
        @start_time = Time.now
        @beat_timer = EM.add_periodic_timer(@sec_per_beat) do
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
    EM.cancel_timer(@beat_timer) if @beat_timer

    @started = nil
  end
end