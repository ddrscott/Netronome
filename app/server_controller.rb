class ServerController < UIViewController
  include BubbleWrap::KVO
  include LayoutHelper
  include ErrorHelper

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
  end

  def on_entered_background
    logger.debug{'entered background'}
    if @broadcast_socket
      @broadcast_socket.close
      @broadcast_socket = nil
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
    @bpm_label.frame = @bpm_label.frame.up(smallest_dim * 0.2)
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
    @knob.frame = @knob.frame.up(smallest_dim * 0.2)
    view << @knob

    # Audio Switch
    set_fields(@audio_switch ||= UISwitch.alloc.initWithFrame(CGRectZero), accessibilityLabel: 'Beep')
    @audio_switch.when(UIControlEventValueChanged){ on_toggle_beep(@audio_switch.on?) }
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


    # Vibrate Switch
    set_fields(@vibrate_switch ||= UISwitch.alloc.initWithFrame(CGRectZero), accessibilityLabel: 'Vibrate')
    @vibrate_switch.when(UIControlEventValueChanged){ on_toggle_vibrate(@vibrate_switch.on?) }
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
    
    $v = self
  end

  def controlValueDidChange(new_value, sender:view)
    #logger.debug{"new value: #{new_value}"}
    @bpm_label.text = "#{new_value.round}"

    @beater.stop

    @last_sent = nil # reset beacon interval

    @beater.start(new_value.round)
  end

  def on_tap_start_beacon
    logger.debug{'starting beacon...'}
    @beacon ||= Beacon.new
    @beacon.start((data[:interval] || 500).to_f / 1000.0, Beacon::DEFAULT_HOST, Beacon::DEFAULT_PORT)
    logger.debug{'started'}
  end

  def on_tap_stop_beacon
    logger.debug{'stopping beacon...'}
    @beacon.stop if @beacon
    logger.debug{'stopped'}
  end

  def on_toggle_beep(value)

  end

  def on_toggle_vibrate(value)

  end

  def on_toggle_transmit(value)
    if value
      @broadcast_socket ||= begin
        socket = GCDAsyncUdpSocket.alloc.initWithDelegate(self, delegateQueue: Dispatch::Queue.main.dispatch_object)
        if alert_errors {|ptr| socket.enableBroadcast(true, error:ptr)}
          socket
        else
          nil
        end
      end
    else
      @broadcast_socket.close
      @broadcast_socket = nil
    end
  end

  def on_beat(bpm, total_beats)
    pulse(@bpm_label, 0.05, 1.25)
    if @vibrate_switch.on?
      AudioHelper.vibrate()
    end

    if @audio_switch.on?
      @pop_player.play
    end

    if @transmit_switch.on?
      send_broadcast(bpm: bpm, beats: total_beats)
    end
  end

  def send_broadcast(data)
    return unless @broadcast_socket

    @last_sent ||= Time.now
    local_latency = ((Time.now - @last_sent) * 1000).round

    data[:interval] = local_latency
    json_str = BW::JSON.generate(data)
    logger.debug{"broadcasting: #{json_str}"}
    encoded_data = json_str.dataUsingEncoding(NSUTF8StringEncoding)
    @broadcast_socket.sendData(encoded_data, toHost: DEFAULT_HOST, port: DEFAULT_PORT, withTimeout:-1, tag:1)

    @last_sent = Time.now
  end
end
