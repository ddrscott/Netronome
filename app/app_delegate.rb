class AppDelegate
  include BubbleWrap::KVO

  MIN_BPM = 40
  MAX_BPM = 220

  def application(application, didFinishLaunchingWithOptions:launchOptions)
    return true if RUBYMOTION_ENV == 'test'

    @window = UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)
    @window.makeKeyAndVisible


    @server_controller = ServerController.alloc.initWithNibName(nil, bundle: nil)
    @server_controller.title = 'Server'
    @window.rootViewController = @server_controller

    #
    #@main_controller = main_controller()
    #@main_controller.title = 'Test'
    #
    #@tab_controller = UITabBarController.alloc.initWithNibName(nil, bundle: nil)
    #@tab_controller.viewControllers = [@server_controller, @main_controller].compact
    #@window.rootViewController = @tab_controller

    true
  end

  def main_controller
    default_bpm = ((MAX_BPM - MIN_BPM) / 2).round
    sections = [{
                    title: 'Basic',
                    rows: [{
                             title: 'Transmit',
                             key:  :beacon_switch,
                             type: :switch,
                             subtitle: '-'
                           },{
                              title: 'BPM',
                              key: :bpm_slider,
                              type: :slider,
                              range: (MIN_BPM..MAX_BPM),
                              value: default_bpm,
                              subtitle: "#{default_bpm} bpm"
                          },{
                                title: 'Receive',
                                key:  :client_switch,
                                type: :switch,
                                subtitle: '-'
                            }
                           ]
                },{
                    title: 'Server Settings',
                    key: :reply_type,
                    select_one: true,
                    rows: [
                       {
                         title: 'Multicast IP',
                         key: :host,
                         type: :string,
                         value: Beacon::DEFAULT_HOST,
                         auto_correction: :no,
                         auto_capitalization: :none
                       },{
                           title: 'Port',
                           key: :port,
                           type: :number,
                           value: Beacon::DEFAULT_PORT
                       },{
                           title: 'Beacon Interval(ms)',
                           key: :interval,
                           type: :number,
                           value: 500
                       }
                    ]
                }]

    new_form = Formotion::Form.new(sections: sections)

    new_controller = Formotion::FormController.alloc.initWithForm(new_form)
    new_controller.title = App.name

    # init observers
    @beacon_switch = new_form.sections[0].rows[0]
    observe(@beacon_switch, 'value') do |_, new_value|
      if new_value
        on_tap_start_beacon
      else
        on_tap_stop_beacon
      end
    end
    @client_switch = new_form.sections[0].rows[2]
    observe(@client_switch, 'value') do |_, new_value|
      if new_value
        on_tap_start_client
      else
        on_tap_stop_client
      end
    end

    new_controller
  end

  def data
    @main_controller.form.render
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

  def on_tap_start_client
    logger.debug{'starting client...'}
    @client ||= Client.new(self)
    unless @client.started?
      if @client.start(nil, nil)
        logger.debug{'started'}
      else
        @client_switch.value = false
      end
    end
  end

  def on_tap_stop_client
    logger.debug{'stopping client...'}
    @client.stop if @client
    logger.debug{'stopped'}
  end

  def on_received_broadcast(json, address_host)
  end
end
