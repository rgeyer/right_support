class RecTrueClass
    
  def initialize
      @value = true    
  end

  def [](something)
    self
  end
 
  #boolean implementation 
  def ==(other)
    true==other
  end

  def &(other)
    @value & other
  end

  def ^(other)
    @value ^ other
  end

  def to_s
    @value.to_s
  end

  def |(other)
    @value | other
  end
end
