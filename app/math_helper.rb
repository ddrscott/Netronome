# Cribbed from http://stackoverflow.com/questions/7749568/how-can-i-do-standard-deviation-in-ruby
module MathHelper

  def sum(values)
    values.inject(0){|accum, i| accum + i }
  end

  def mean(values)
    sum(values)/values.length.to_f
  end

  def sample_variance(values)
    m = mean(values)
    sum = values.inject(0){|accum, i| accum +(i-m)**2 }
    sum/(values.length - 1).to_f
  end

  def standard_deviation(values)
    return Math.sqrt(sample_variance(values))
  end

end