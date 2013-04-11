class ServerController < UIViewController
  include BubbleWrap::KVO
  include LayoutHelper
  include ErrorHelper
  include DispatchHelper

  BEACON_INTERVAL = 0.25

  DEFAULT_BPM = 60
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

    NSNotificationCenter.defaultCenter.addObserver(self, selector: :on_entered_background, name:UIApplicationDidEnterBackgroundNotification, object:nil)
  end

  def viewWillDisappear(animated)
    NSNotificationCenter.defaultCenter.removeObserver(self, name:UIApplicationDidEnterBackgroundNotification, object:nil)

    @transmit_switch.on = false
    on_tap_stop_beacon
  end

  def on_entered_background
    logger.debug{'entered background'}
  end

  def init_views
    padding = 20

    self.view.backgroundColor = UIColor.wood

    smallest_dim = [view.bounds.width, view.bounds.height].min

    # BPM Label
    set_fields(@bpm_label ||= UILabel.alloc.initWithFrame(CGRectZero),
               frame: CGRect.make(width: view.bounds.width, height: smallest_dim * 0.20),
               font: UIFont.boldSystemFontOfSize(smallest_dim * 0.20),
               text: DEFAULT_BPM.to_s,
               textColor: UIColor.pea_green,
               shadowColor: 0x000000.uicolor,
               backgroundColor: UIColor.clearColor,
               textAlignment: UITextAlignmentCenter
    )
    @bpm_label.center = view.bounds.center
    if view.bounds.height > view.bounds.width # portrait
      @bpm_label.frame = @bpm_label.frame.up(smallest_dim * 0.1)
    end
    view << @bpm_label

    # Knob
    set_fields(@knob ||= DCKnob.alloc.initWithDelegate(self),
                       frame: CGRect.make(width: smallest_dim * 0.66, height: smallest_dim * 0.66),
                       color: UIColor.pea_green,
                       backgroundColor: UIColor.clearColor,
                       backgroundColorAlpha: 0.5,
                       min: MIN_BPM,
                       max: MAX_BPM,
                       value: DEFAULT_BPM,
                       valueArcWidth: smallest_dim * 0.09
    )
    @knob.displaysValue = false
    @knob.allowsGestures = false
    set_fields(@knob.layer, shadowOffset: CGSizeMake(0,0), shadowColor: UIColor.blackColor.CGColor, shadowRadius: 20, shadowOpacity: 0.85)
    @knob.center = @bpm_label.center
    view << @knob

    observe(@knob, :value){|_, new_value| @bpm_label.text = "#{new_value.round}"}

    # Arc Label
    set_fields(@arc_label ||= UILabel.alloc.initWithFrame(CGRectZero),
               frame: CGRect.make(width: view.bounds.width, height: @knob.valueArcWidth),
               font: UIFont.boldSystemFontOfSize(smallest_dim * 0.06),
               text: 'BPM',
               textColor: UIColor.pea_green,
               shadowColor: 0x000000.uicolor,
               backgroundColor: UIColor.clearColor,
               textAlignment: UITextAlignmentCenter
    )
    @arc_label.center = @bpm_label.center
    @arc_label.frame = @arc_label.frame.down(@knob.frame.height / 2).up(@arc_label.frame.height * 0.75)
    view << @arc_label

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

    # Vibrate Switch
    set_fields(@vibrate_switch ||= UISwitch.alloc.initWithFrame(CGRectZero), accessibilityLabel: 'Vibrate')
    @vibrate_switch.when(UIControlEventValueChanged){ keep_awake_if_needed }
    @vibrate_switch.sizeToFit
    @vibrate_switch.frame = CGRect.make(origin: view.bounds.bottom_left, size: @vibrate_switch.frame.size).up(@vibrate_switch.frame.height * 2 + padding * 3).right(padding)
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
    
    
    # Debug Label
    debug_font = UIFont.boldSystemFontOfSize(12)
    set_fields(@debug_label ||= UILabel.alloc.initWithFrame(CGRectZero),
               frame: view.bounds.height(debug_font.lineHeight).y(0),
               font: debug_font,
               text: 'Millis',
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

    @beater.stop

    @last_sent = nil # reset beacon interval

    if @listen_switch.blank? or !@listen_switch.on?
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
      @beacon ||= Beacon.new
      @beacon.start(BEACON_INTERVAL, DEFAULT_HOST, DEFAULT_PORT)
    else
      @beacon.stop
    end
    start_debug_timer
  end

  def on_toggle_listen(value)
    keep_awake_if_needed

    @client.stop
    @beater.stop

    if value
      @client.start(DEFAULT_HOST, DEFAULT_PORT)
      wobble(@bpm_label, 0.25, 0.25)
      @bpm_label.textColor = @knob.color = @arc_label.color = @listen_switch.onTintColor
    else
      wobble(@bpm_label, false)
      @bpm_label.textColor = @knob.color = @arc_label.color = @audio_switch.onTintColor
      @beater.start(@knob.value.round)
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

    if @transmit_switch.on?
      broadcast_beat
    end
  end

  def broadcast_beat
    if @beacon and @beacon.started?
      beat_time_ms = ((Time.now - @beacon.start_time) * 1000).round
      packet = BeatPacket.new(beat_time_ms, @beater.bpm)
      logger.debug{"broadcasting: #{packet}"}
      encoded_data = packet.to_s.dataUsingEncoding(NSUTF8StringEncoding)
      @beacon.udp_socket.sendData(encoded_data, toHost: DEFAULT_HOST, port: DEFAULT_PORT, withTimeout:-1, tag:1)
    end
  end

  def on_received_broadcast(data, address_host)
    #puts "#{address_host}: #{data}"

    if data.index('bp|') == 0
      packet = BeatPacket.parse(data)
      on_beat_packet(packet)
    else
      logger.warn{"unknown packet: #{data}"}
    end
  end

  # TODO reset local beat timer to latency average
  def on_beat_packet(packet)
    if !@client.started? and @last_received_beat and @last_received_beat.bpm != packet.bpm
      on_toggle_listen(true)
    end

    @last_received_beat = packet
    EM.schedule_on_main do
      @knob.delegate = nil
      @knob.value = @last_received_beat.bpm
      @knob.delegate = self
    end
  end

  def on_local_offset_updated
    logger.debug{"local offset should be: #{@client.local_offset}, my time is: #{Time.now_ms}, s - c => #{Time.now_ms + @client.local_offset}".ascii_cyan}

    @client.stop
    @beater.stop
    Dispatch::Queue.main.async do
      start_debug_timer

      wobble(@bpm_label, false)

      if @last_received_beat
        offset_ms = @client.server_time_ms - @last_received_beat.time_ms
        beat_sec = 60.0 / @last_received_beat.bpm
        logger.debug{"starting beater at #{@last_received_beat.bpm} bpm, beat time: #{@last_received_beat.time_ms}, s: #{@client.server_time_ms}, offset: #{offset_ms}"}
        @beater.start(@last_received_beat.bpm, beat_sec - (offset_ms % beat_sec))
      end
    end
  end

  def start_debug_timer
    EM.cancel_timer(@debug_timer) if @debug_timer

    delay_till = if @client.server_time_ms
      @client.till_server_next_sec
    else
      Time.till_next_second
    end

    @debug_timer = EM.add_timer(delay_till) do
      @debug_timer = EM.add_periodic_timer(1.0) do
        if @beacon and @beacon.started?
          @debug_label.text = "Beacon: #{@beacon.elapsed} ms";
        elsif @client.server_time_ms
          @debug_label.text = "Est: #{(@client.server_time_ms).round} ms"
        else
          @debug_label.text = "Now: #{Time.now_ms} ms";
        end
        @debug_label.setNeedsDisplay
      end
    end
  end
end
