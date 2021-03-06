#!/bin/env ruby
# encoding: utf-8

# The class to supply interpolation methods
class Interp
  attr_reader :spectrum

  public

  def initialize(x, y)
    @spectrum = [x, y].transpose.sort_by { |t| t[0] }
  end

  def linask(x)
    x1, y1, x2, y2 = find_points(x)
    (x - x1) * (y2 -  y1) / (x2 - x1) + y1
  end

  def lnask(x)
    x1, y1, x2, y2 = find_points(x)
    x, x1, y1, x2, y2 = [x, x1, y1, x2, y2].map { |v| Math.log([v, 1e-300].max) }

    logy = (x - x1) * (y2 -  y1) / (x2 - x1) + y1
    Math.exp(logy)
  end

  private

  def find_points(x)
    uind = @spectrum.find_index { |term| term[0] > x } || (@spectrum.size -  1)
    uind += 1 if uind == 0
    lind = uind - 1

    [@spectrum[lind][0], @spectrum[lind][1],
      @spectrum[uind][0], @spectrum[uind][1]]
  end
end
