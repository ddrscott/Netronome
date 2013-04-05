class Beacon
  include ErrorHelper

  def initialize
    @queue = Dispatch::Queue.send :new, "#{App.identifier}.beacon"

    @udp_socket = GCDAsyncUdpSocket.alloc.initWithDelegate(self, delegateQueue: @queue.dispatch_object)

    alert_errors {|ptr| @udp_socket.enableBroadcast(true, error:ptr)}
  end

  def started?
    @started
  end

  def start(interval, host, port)
    stop if @started

    @beacon_timer = EM.add_periodic_timer(interval) do
      broadcast_package
    end

    @interval, @host, @port = interval, host, port

    @started = true
  end

  def stop
    EM.cancel_timer(@beacon_timer)
    @udp_socket.close

    @beacon_timer = nil
    @started = false
  end

  def broadcast_package
    packet = TimingPacket.new(Time.now_ms, @interval)

    logger.debug{"broadcasting: #{packet.to_s}"}
    encoded_data = packet.to_s.dataUsingEncoding(NSUTF8StringEncoding)
    @udp_socket.sendData(encoded_data, toHost: @host, port: @port, withTimeout:-1, tag:1)
  end
end