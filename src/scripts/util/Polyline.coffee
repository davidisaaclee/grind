_ = require 'lodash'

###
Wraps multiple Phaser.Line objects into a polyline.
###
class Polyline
  # calculate the total length of multiple segments
  @calculateLength: (segments) ->
    _ segments
      .map _.property 'length'
      .reduce _.add

  constructor: (segments) ->
    Object.defineProperty this, 'segments',
      value: segments
      writable: false
      enumerable: true
      configurable: false

    @_detailedSegments = @segments.map (segment, idx) =>
      segment.__polylineIndex = idx
      segment: segment
      next: @segments[idx + 1]
      previous: @segments[idx - 1]

    @length = Polyline.calculateLength @segments

  next: (segment) -> @_detailedSegments[segment.__polylineIndex].next

  previous: (segment) -> @_detailedSegments[segment.__polylineIndex].previous


module.exports = Polyline