class Client
  include ErrorHelper

  def started?
    @started
  end

  def start(host, port)
    stop if @started

    @socket = GCDAsyncUdpSocket.alloc.initWithDelegate(self, delegateQueue:Dispatch::Queue.main.dispatch_object)

    @started = alert_errors {|ptr| @socket.bindToPort(Beacon::DEFAULT_PORT, error:ptr)} and
        alert_errors {|ptr| @socket.joinMulticastGroup(Beacon::DEFAULT_HOST, error:ptr)} and
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
    logger.debug{"data: #{data}, tag: #{tag}"}

    # send it back for some reason as an ACK (maybe?)
    @socket.sendData(data, toAddress:address, withTimeout:-1, tag:0)
  end
end