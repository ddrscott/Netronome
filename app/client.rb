class Client
  include ErrorHelper
  include MathHelper

  attr_reader :local_offset

  def initialize(delegate)
    @queue = Dispatch::Queue.send :new, "#{App.identifier}.client"
    @delegate = delegate
  end

  def started?
    @started
  end

  def start(host, port)
    stop if @started


    @local_offset = nil
    @last_timing_packet = nil
    if @timing_packets
      @timing_packets.clear
    else
      @timing_packets = []
    end

    @socket = GCDAsyncUdpSocket.alloc.initWithDelegate(self, delegateQueue: @queue.dispatch_object)

    @started = alert_errors {|ptr| @socket.bindToPort(port, error:ptr)} and
        alert_errors {|ptr| @socket.joinMulticastGroup(host, error:ptr)} and
          alert_errors {|ptr| @socket.beginReceiving(ptr)}

    if @started
      @host = host
      @port = @socket.localPort
      logger.debug{"@host => #{@host}, @port => #{@port}"}
    end
    unless @started
      self.stop
    end

    @started
  end

  def stop
    if @socket
      alert_errors {|ptr| @socket.leaveMulticastGroup(@host, error:ptr) }
      @socket.close
      @socket = nil
    end
    @started = false
  end

  #  /**
  #   * Called when the socket has received the requested datagram.
  #   **/
  #  - (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
  #     fromAddress:(NSData *)address
  #     withFilterContext:(id)filterContext;
  def udpSocket(sock, didReceiveData:data, fromAddress: address, withFilterContext:tag)
    address_host = GCDAsyncUdpSocket.hostFromAddress(address)
    data_str = "#{data}"

    if data_str.index('tm|') == 0
      packet = TimingPacket.parse(data_str)
      packet.received_ms = Time.now_ms
      on_timing_packet(packet)
    else
      @delegate.on_received_broadcast(data_str, address_host)
    end
  end

  def on_timing_packet(packet)
    print 't'

    if @last_timing_packet.blank?
      @timing_packets.clear
    elsif (packet.received_ms - @last_timing_packet.received_ms) < packet.interval
      logger.debug{"received packet faster than interval?!?"}
      #@timing_packets.clear
      return
    elsif packet.time_ms > @last_timing_packet.time_ms
      # only consider packets in the correct order

      @last_timing_packet.latency = packet.received_ms - @last_timing_packet.received_ms

      @timing_packets << @last_timing_packet
    end
    @last_timing_packet = packet

    if @timing_packets.size > 3
      @timing_packets.shift

      latencies = @timing_packets.collect{|c| c.latency}
      std_dev = standard_deviation(latencies)

      logger.debug{"std_dev => #{std_dev}, #{latencies}"}
      if std_dev < 10
        offsets = @timing_packets.collect do |tp|
          s = tp.time_ms
          c = tp.received_ms
          l = tp.latency
          # logger.debug{"\tl => #{l}, s => #{s}, c => #{c}, s - c => #{s - c}"}
          l - tp.interval
        end
        avg_latency = mean(offsets)
        # logger.debug{"@last_timing_packet is #{@last_timing_packet.to_s}"}

        time_diff = @last_timing_packet.time_ms - @last_timing_packet.received_ms

        @local_offset = (time_diff + avg_latency).to_i

        if @delegate.respond_to? :on_local_offset_updated
          @delegate.on_local_offset_updated
        end
      end
    end
  end

  def server_time_ms
    if self.local_offset
      Time.now.to_f * 1000.0 + self.local_offset
    else
      nil
    end
  end
end