module ErrorHelper

  def log_error(error, backtrace)
    msg = "error: [#{error.code}] #{error.localizedDescription}"
    logger.error{"#{msg} at #{backtrace * "\n\t"}"}
    msg
  end

  def raise_errors(&block)
    error_ptr = Pointer.new(:object)
    result = block.call(error_ptr)
    raise log_error(error_ptr[0], caller) if error_ptr[0]
    result
  end

  def alert_errors(&block)
    error_ptr = Pointer.new(:object)
    result = block.call(error_ptr)
    App.alert(log_error(error_ptr[0], caller)) if error_ptr[0]
    result
  end
end