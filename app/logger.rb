# TODO convert to use asl_log
# http://doing-it-wrong.mikeweller.com/2012/07/youre-doing-it-wrong-1-nslogdebug-ios.html
class Logger

  def initialize(tag)
    @tag = tag.to_s
    @@last_log_time ||= Time.now
  end

  def debug(&block)
    log(__method__.upcase, &block)
  end
  def info(&block)
    log(__method__.upcase, &block)
  end
  def warn(&block)
    log(__method__.upcase, &block)
  end
  def error(&block)
    if Device.simulator?
      log("\e[31m#{__method__.upcase}\e[0m\a", &block)
      else
      log(__method__.upcase, &block)
    end
  end
  def fatal(&block)
    log(__method__.upcase, &block)
  end

  def trace(&block)
    log(__method__.upcase, &block)
  end

  # TODO call block based on severity
  #
  # Don't use String#% method - https://groups.google.com/forum/?fromgroups=#!topic/rubymotion/fxGAmnaf0uE
  def log(severity, &block)
    return unless Device.simulator?

    message = block.call
    timing = "#{((Time.now - @@last_log_time) * 1000).round} ms"
    before_severity = "#{timing.rjust(8)} [#{@tag.ljust(20)}]"
    caller_src_line = parse_caller(caller.dup)
    formatted_message = "#{before_severity} #{severity} #{message} #{"[#{caller_src_line}]".ascii_blue}"

    NSLog(formatted_message)

    @@last_log_time = Time.now
  rescue Exception
    NSLog("could not log message due to #{$!.message}")
  end

  def parse_caller(call_stack)
    line = call_stack[1] || call_stack[0]
    if line
      line.strip.split(':in').first
    else
      '?'
    end
  end
end

module LogHelper
  def logger
    @__logger ||= Logger.new(self.class)
  end
end

class Object
  include LogHelper
end