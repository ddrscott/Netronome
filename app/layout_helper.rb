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

  #def set_shadow(view, options)
  #  layer = view.layer
  #  options.each do |k, v|
  #    begin
  #      setter = "shadow#{k.to_s.camelcase}="
  #      if layer.respond_to? setter
  #        layer.send setter, v
  #      else
  #        logger.warn{"#{k} does not respond to #{setter}"}
  #      end
  #    rescue Exception
  #      logger.error{"could not set field #{k} in #{view} due to #{$!.message}"}
  #    end
  #  end
  #  view
  #end

  def pulse(view, duration, scale)
    pulseAnimation = CABasicAnimation.animationWithKeyPath('transform.scale')
    pulseAnimation.duration = duration
    pulseAnimation.toValue = scale
    pulseAnimation.timingFunction = CAMediaTimingFunction.functionWithName(KCAMediaTimingFunctionEaseInEaseOut)
    pulseAnimation.autoreverses = true
    pulseAnimation.repeatCount = 0

    view.layer.addAnimation(pulseAnimation, forKey:nil)
  end

  def wobble(view, duration_or_false = 0.13, rotation = 0.02)

    if duration_or_false
      shake = CABasicAnimation.animationWithKeyPath("transform")
      shake.duration = duration_or_false
      shake.autoreverses = true
      shake.repeatCount  = 999_999_999_999.0
      shake.removedOnCompletion = false
      shake.fromValue = NSValue.valueWithCATransform3D(CATransform3DRotate(view.layer.transform,-rotation, 0.0 ,0.0 ,1.0))
      shake.toValue   = NSValue.valueWithCATransform3D(CATransform3DRotate(view.layer.transform, rotation, 0.0 ,0.0 ,1.0))

      view.layer.addAnimation(shake, forKey: 'wobble')
    else
      view.layer.removeAnimationForKey('wobble')
    end
  end
end