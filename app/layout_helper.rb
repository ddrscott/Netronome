module LayoutHelper
  def set_fields(lay, options)
    options.each do |k, v|
      begin
        setter = "#{k}="
        if lay.respond_to? setter
          lay.send setter, v
        elsif k == :margin
          if Array === v
            lay.topMargin = v[0]
            lay.rightMargin = v[1]
            lay.bottomMargin = v[2]
            lay.leftMargin = v[3]
          else
            lay.topMargin = v
            lay.rightMargin = v
            lay.bottomMargin = v
            lay.leftMargin = v
          end
        elsif k == :setWidth
          lay.setSizeWithWidth(v)
        elsif k == :setHeight
          lay.setSizeWithHeight(v)
        else
          logger.warn{"#{k} does not respond to #{setter}"}
        end
      rescue Exception
        logger.error{"could not set field #{k} in #{lay} due to #{$!.message}"}
      end
    end
    lay
  end

  def pulse(view, duration, scale)
    pulseAnimation = CABasicAnimation.animationWithKeyPath('transform.scale')
    pulseAnimation.duration = duration
    pulseAnimation.toValue = scale
    pulseAnimation.timingFunction = CAMediaTimingFunction.functionWithName(KCAMediaTimingFunctionEaseInEaseOut)
    pulseAnimation.autoreverses = true
    pulseAnimation.repeatCount = 0

    view.layer.addAnimation(pulseAnimation, forKey:nil)
  end
end