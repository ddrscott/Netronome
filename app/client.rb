class Client
  include ErrorHelper

  def initialize(delegate)
    @queue = Dispatch::Queue.send :new, "#{App.identifier}.client"
    @delegate = delegate
  end

  def started?
    @started
  end

  def start(host, port)
    stop if @started

    @socket = GCDAsyncUdpSocket.alloc.initWithDelegate(self, delegateQueue: @queue.dispatch_object)

    @started = alert_errors {|ptr| @socket.bindToPort(port, error:ptr)} and
        alert_errors {|ptr| @socket.joinMulticastGroup(host, error:ptr)} and
          alert_errors {|ptr| @socket.beginReceiving(ptr)}

    if @started
      @host = @socket.localHost
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
      alert_errors {|ptr| @socket.leaveMulticastGroup(Beacon::DEFAULT_HOST, error:ptr) }
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
    @delegate.on_received_broadcast(data_str, address_host)
  end
end