module DispatchHelper

  def delay_till_next_second(&block)
    EM.cancel_timer(@delay_till_next_second_timer) if @delay_till_next_second_timer
    @delay_till_next_second_timer = EM.add_timer(Time.till_next_second) do
      block.call
    end
  end

  def delay_for_second(duration, &block)
    EM.cancel_timer(@delay_for_second) if @delay_for_second
    @delay_for_second = EM.add_timer(duration) do
      block.call
    end
  end
end
