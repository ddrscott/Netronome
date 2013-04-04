class Beacon
  include ErrorHelper
  include Formotion::Formable

  DEFAULT_HOST = '225.228.0.187'
  DEFAULT_PORT = 18709

  attr_accessor :total_beacons, :bpm, :host, :port

  def initialize
    @bpm = 90

    @udp_socket = GCDAsyncUdpSocket.alloc.initWithDelegate(self, delegateQueue: Dispatch::Queue.main.dispatch_object)

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
    @total_beacons = 0
    @last_sent = Time.now

    @host = host
    @port = port

    @started = true
  end

  def stop
    @udp_socket.close

    EM.cancel_timer(@beacon_timer)
    @beacon_timer = nil
    @started = false
  end

  def broadcast_package(bpm)
    @total_beacons ||= 0
    @last_sent ||= Time.now
    @host ||= DEFAULT_HOST
    @port ||= DEFAULT_PORT

    @total_beacons += 1

    local_latency = (Time.now - @last_sent) * 1000.0

    decoded_data = "bpm|#{@total_beacons}|#{local_latency.round}|#{@bpm}\n"
    # print decoded_data
    encoded_data = decoded_data.dataUsingEncoding(NSUTF8StringEncoding)
    @udp_socket.sendData(encoded_data, toHost: @host, port: @port, withTimeout:-1, tag:1)
    @last_sent = Time.now
  end
end