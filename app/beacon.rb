class Beacon
  include ErrorHelper
  include DispatchHelper

  def initialize
    @queue = Dispatch::Queue.send :new, "#{App.identifier}.beacon"

    @udp_socket = GCDAsyncUdpSocket.alloc.initWithDelegate(self, delegateQueue: @queue.dispatch_object)

    alert_errors {|ptr| @udp_socket.enableBroadcast(true, error:ptr)}
  end

  def started?
    @started
  end

  def start_time
    @started
  end

  def start(interval, host, port)
    stop if @started

    @started = Time.now

    delay_till_next_second do
      @beacon_timer = EM.add_periodic_timer(interval) do
        broadcast_package
      end
    end

    @interval, @host, @port = interval, host, port
  end

  def stop
    EM.cancel_timer(@beacon_timer)
    @udp_socket.close

    @beacon_timer = nil
    @started = nil
  end

  def elapsed
    if started?
      ((Time.now - @started) * 1000).to_i
    else
      0
    end
  end
  def broadcast_package
    return unless @started

    packet = TimingPacket.new(elapsed(), (@interval * 1000).to_i)

    #logger.debug{"broadcasting: #{packet.to_s}"}
    encoded_data = packet.to_s.dataUsingEncoding(NSUTF8StringEncoding)
    @udp_socket.sendData(encoded_data, toHost: @host, port: @port, withTimeout:-1, tag:1)
  end
end