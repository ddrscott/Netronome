class ServerController < UIViewController
  include BubbleWrap::KVO
  include LayoutHelper
  include ErrorHelper
  include MathHelper

  BEACON_INTERVAL = 0.25

  MIN_BPM = 40
  MAX_BPM = 220

  DEFAULT_HOST = '225.228.0.187'
  DEFAULT_PORT = 18709

  # setup views
  def viewDidLoad
    @beater = Beater.new(self)

    pop_wav = NSURL.fileURLWithPath(File.join(NSBundle.mainBundle.resourcePath, 'pop.wav'))
    @pop_player = AVAudioPlayer.alloc.initWithContentsOfURL(pop_wav, error:nil)
    @pop_player.prepareToPlay
    @client = Client.new(self)
    @timing_packets = []
    @timing_mutex = Mutex.new
  end

  def viewWillLayoutSubviews
    init_views()
  end

  def viewWillAppear(animated)
    super

    EM.add_periodic_timer(1.0) do
      @debug_label.text = "#{Time.now_ms}"; @debug_label.setNeedsDisplay
    end

    NSNotificationCenter.defaultCenter.addObserver(self, selector: :on_entered_background, name:UIApplicationDidEnterBackgroundNotification, object:nil)
  end

  def viewWillDisappear(animated)
    NSNotificationCenter.defaultCenter.removeObserver(self, name:UIApplicationDidEnterBackgroundNotification, object:nil)

    @transmit_switch.on = false
    on_tap_stop_beacon
  end

  def on_entered_background
    logger.debug{'entered background'}
    if @beat_socket
      @beat_socket.close
      @beat_socket = nil
    end
  end

  def init_views
    padding = 20

    self.view.backgroundColor = UIColor.wood

    smallest_dim = [view.bounds.width, view.bounds.height].min

    # BPM Label
    set_fields(@bpm_label ||= UILabel.alloc.initWithFrame(CGRectZero),
               frame: CGRect.make(width: 200, height: 50),
               font: UIFont.boldSystemFontOfSize(50),
               text: 'BPM',
               textColor: UIColor.pea_green,
               shadowColor: 0x000000.uicolor,
               backgroundColor: UIColor.clearColor,
               textAlignment: UITextAlignmentCenter
    )
    @bpm_label.center = view.center
    @bpm_label.frame = @bpm_label.frame.up(smallest_dim * 0.33)
    view << @bpm_label

    # Knob
    set_fields(@knob ||= DCKnob.alloc.initWithDelegate(self),
                       frame: CGRect.make(width: smallest_dim * 0.66, height: smallest_dim * 0.66),
                       color: UIColor.pea_green,
                       backgroundColor: UIColor.clearColor,
                       backgroundColorAlpha: 0.5,
                       min: MIN_BPM,
                       max: MAX_BPM,
                       value: (MAX_BPM - MIN_BPM) / 2 + MIN_BPM,
                       valueArcWidth: 25
    )
    @knob.displaysValue = false
    @knob.allowsGestures = false
    set_fields(@knob.layer, shadowOffset: CGSizeMake(0,0), shadowColor: UIColor.blackColor.CGColor, shadowRadius: 20, shadowOpacity: 0.85)

    @knob.center = view.center
    @knob.frame = @knob.frame.up(smallest_dim * 0.33)
    view << @knob

    # Audio Switch
    set_fields(@audio_switch ||= UISwitch.alloc.initWithFrame(CGRectZero), accessibilityLabel: 'Beep')
    @audio_switch.when(UIControlEventValueChanged){ keep_awake_if_needed }
    @audio_switch.sizeToFit
    @audio_switch.frame = CGRect.make(origin: view.bounds.bottom_left, size: @audio_switch.frame.size).up(@audio_switch.frame.height + padding).right(padding)
    @audio_switch.onTintColor = UIColor.pea_green
    view << @audio_switch

    # Audio Label
    set_fields(@audio_label ||= UILabel.alloc.initWithFrame(CGRectZero),
               frame: @audio_switch.frame.up(@audio_switch.frame.height),
               font: UIFont.boldSystemFontOfSize(UIFont.labelFontSize),
               text: 'Beep',
               textColor: UIColor.whiteColor,
               shadowColor: 0x000000.uicolor,
               backgroundColor: UIColor.clearColor,
               textAlignment: UITextAlignmentCenter
    )
    view << @audio_label

    # Transmit Switch
    set_fields(@transmit_switch ||= UISwitch.alloc.initWithFrame(CGRectZero), accessibilityLabel: 'Transmit')
    @transmit_switch.when(UIControlEventValueChanged){ on_toggle_transmit(@transmit_switch.on?) }
    @transmit_switch.sizeToFit
    @transmit_switch.frame = CGRect.make(origin: view.bounds.bottom_right, size: @transmit_switch.frame.size).up(@transmit_switch.frame.height + padding).left(@transmit_switch.frame.width + padding)
    @transmit_switch.onTintColor = UIColor.pea_green
    view << @transmit_switch

    # Transmit Label
    set_fields(@transmit_label ||= UILabel.alloc.initWithFrame(CGRectZero),
               frame: @transmit_switch.frame.up(@transmit_switch.frame.height),
               font: UIFont.boldSystemFontOfSize(UIFont.labelFontSize),
               text: 'Transmit',
               textColor: UIColor.whiteColor,
               shadowColor: 0x000000.uicolor,
               backgroundColor: UIColor.clearColor,
               textAlignment: UITextAlignmentCenter
    )
    view << @transmit_label


    # Listen Switch
    set_fields(@listen_switch ||= UISwitch.alloc.initWithFrame(CGRectZero), accessibilityLabel: 'Listen')
    @listen_switch.when(UIControlEventValueChanged){ on_toggle_listen(@listen_switch.on?) }
    @listen_switch.sizeToFit
    @listen_switch.frame = CGRect.make(origin: view.bounds.bottom_right, size: @listen_switch.frame.size).up(@listen_switch.frame.height * 2 + padding * 3).left(@listen_switch.frame.width + padding)
    @listen_switch.onTintColor = UIColor.ocean_blue
    view << @listen_switch

    # Listen Label
    set_fields(@listen_label ||= UILabel.alloc.initWithFrame(CGRectZero),
               frame: @listen_switch.frame.up(@listen_switch.frame.height),
               font: UIFont.boldSystemFontOfSize(UIFont.labelFontSize),
               text: 'Listen',
               textColor: UIColor.whiteColor,
               shadowColor: 0x000000.uicolor,
               backgroundColor: UIColor.clearColor,
               textAlignment: UITextAlignmentCenter
    )
    view << @listen_label
    
    
    
    # Vibrate Switch
    set_fields(@vibrate_switch ||= UISwitch.alloc.initWithFrame(CGRectZero), accessibilityLabel: 'Vibrate')
    @vibrate_switch.when(UIControlEventValueChanged){ keep_awake_if_needed }
    @vibrate_switch.sizeToFit
    @vibrate_switch.frame = CGRect.make(origin: view.bounds.bottom_center, size: @vibrate_switch.frame.size).up(@vibrate_switch.frame.height + padding).left(@vibrate_switch.frame.width / 2)
    @vibrate_switch.onTintColor = UIColor.pea_green
    view << @vibrate_switch

    # Vibrate Label
    set_fields(@vibrate_label ||= UILabel.alloc.initWithFrame(CGRectZero),
               frame: @vibrate_switch.frame.up(@vibrate_switch.frame.height),
               font: UIFont.boldSystemFontOfSize(UIFont.labelFontSize),
               text: 'Vibrate',
               textColor: UIColor.whiteColor,
               shadowColor: 0x000000.uicolor,
               backgroundColor: UIColor.clearColor,
               textAlignment: UITextAlignmentCenter
    )
    view << @vibrate_label

    # Debug Label
    debug_font = UIFont.boldSystemFontOfSize(12)
    set_fields(@debug_label ||= UILabel.alloc.initWithFrame(CGRectZero),
               frame: view.frame.height(debug_font.lineHeight).y(0),
               font: debug_font,
               textColor: UIColor.whiteColor,
               backgroundColor: 0x111111.uicolor,
               textAlignment: UITextAlignmentRight
    )
    set_fields(@debug_label.layer, shadowOffset: CGSizeMake(0,3), shadowColor: UIColor.blackColor.CGColor, shadowRadius: 3, shadowOpacity: 1)
    view << @debug_label

    $s = self
  end

  def controlValueDidChange(new_value, sender:view)
    logger.debug{"new value: #{new_value}"}
    @bpm_label.text = "#{new_value.round}"

    @beater.stop

    @last_sent = nil # reset beacon interval

    if @listen_switch and !@listen_switch.on?
      @beater.start(new_value.round)
    end
  end

  def keep_awake_if_needed
    keep_on = !!view.subviews.detect{|s| UISwitch === s and s.on?}
    UIApplication.sharedApplication.idleTimerDisabled = keep_on
  end

  def on_toggle_transmit(value)
    keep_awake_if_needed

    if value
      @beat_socket = begin
        socket = GCDAsyncUdpSocket.alloc.initWithDelegate(self, delegateQueue: Dispatch::Queue.main.dispatch_object)
        if alert_errors {|ptr| socket.enableBroadcast(true, error:ptr)}
          socket
        else
          nil
        end
      end

      @beacon ||= Beacon.new
      @beacon.start(BEACON_INTERVAL, DEFAULT_HOST, DEFAULT_PORT)
    elsif @beat_socket
      @beat_socket.close
      @beacon.stop
    end
  end

  def on_toggle_listen(value)
    keep_awake_if_needed

    @client.stop
    @beater.stop

    if value
      # reset samples
      @last_timing_packet = nil
      @client.start(DEFAULT_HOST, DEFAULT_PORT)
      wobble(@bpm_label, 0.25, 0.25)
      @bpm_label.textColor = @knob.color = @listen_switch.onTintColor
    else
      @bpm_label.textColor = @knob.color = @audio_switch.onTintColor
    end
    @knob.setNeedsDisplay
  end

  def render_beat
    pulse(@bpm_label, 0.05, 1.25)

    if @vibrate_switch.on?
      AudioHelper.vibrate()
    end

    if @audio_switch.on?
      @pop_player.play
    end
  end

  def on_beat(beater)
    render_beat

    if !@listen_switch.on? and @transmit_switch.on?
      broadcast_beat
    end
  end

  def broadcast_beat
    unless @beat_socket
      logger.error{'@broadcast_socket is nil'}
      return
    end
    packet = BeatPacket.new(Time.now_ms, @beater.bpm)
    logger.debug{"broadcasting: #{packet}"}
    encoded_data = packet.to_s.dataUsingEncoding(NSUTF8StringEncoding)
    @beat_socket.sendData(encoded_data, toHost: DEFAULT_HOST, port: DEFAULT_PORT, withTimeout:-1, tag:1)
  end

  def on_received_broadcast(data, address_host)
    #puts "#{address_host}: #{data}"

    if data.index('bp|') == 0
      packet = BeatPacket.parse(data)
      on_beat_packet(packet)
    elsif data.index('tm|') == 0
      packet = TimingPacket.parse(data)
      packet.received_ms = Time.now_ms
      on_timing_packet(packet)
    else
      logger.warn{"unknown packet: #{data}"}
    end
  end

  # TODO reset local beat timer to latency average
  def on_beat_packet(packet)
    Dispatch::Queue.main.async do

      @last_received_beat = packet

      @bpm_label.text = "#{@last_received_beat.bpm}"

      @knob.delegate = nil
      @knob.value = @last_received_beat.bpm
      @knob.setNeedsDisplay
      @knob.delegate = self
    end
  end

  def on_timing_packet(packet)
    print 't'

    if @last_timing_packet.blank?
      @timing_packets.clear
    elsif (packet.received_ms - @last_timing_packet.received_ms) < packet.interval
      @timing_packets.clear
    elsif @last_timing_packet.time_ms < packet.time_ms # only consider packets in the correct order
      # calc latency
      @last_timing_packet.latency = packet.received_ms - @last_timing_packet.received_ms - @last_timing_packet.interval

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
          offset = s - c - l
          logger.debug{"l => #{l}, s => #{s}, c => #{c}, s - c => #{s - c}, offset: #{offset}"}
          offset
        end
        avg_offset = mean(offsets)
        Dispatch::Queue.main.async do
          wobble(@bpm_label, false)

          @beater.stop
          @beater.start(@last_received_beat.bpm, @last_received_beat.time_ms - Time.now_ms + avg_offset)
          @client.stop
        end
      end

      #if @timing_packets.size > 10
      #  # calc std deviation
      #  latencies = @timing_packets.collect{|c| c.latency}
      #  std_dev = standard_deviation(latencies)
      #  # throw away stuff that's not in range
      #
      #  logger.debug{"#{latencies * ', '} => #{std_dev.round(2)}"}
      #
      #  @timing_packets.reject!{|r| r.latency > std_dev}
      #else
      #  # not enough packets
      #end
    end
  end
end
