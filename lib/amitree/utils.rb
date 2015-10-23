module Enumerable
  def map_detect &block
    lazy.map(&block).detect{|x| x}
  end
end
