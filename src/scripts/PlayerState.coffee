k = require 'Constants'
_ = require 'lodash'

modeCodes =
  WALK: 0
  JUMP: 1
  FALL: 2
  GRIND: 3
  GRAPPLE: 4
  FLY: 5

class PlayerState
  name: 'NONE'

  # check if `player` accepts this mode and transitions
  # puts any data in `out_data`
  # returns true if accepted, else false
  accept: (player, game, input, out_data) ->
    console.log 'You need to override `accept()`.'
    return false

  # called when state is entered
  enter: (player, game, data) ->

  # called when state is exited
  exit: (player, game) ->

  update: (player, game, input) ->
    console.log 'You need to override `update()`.'

  checkAccepts: (player, game, input, stateStack) ->
    for state in stateStack
      out_data = {}
      if state.accept player, game, input, out_data
        player.setMode modeCodes[state.name], out_data
        return state
    return null


applyGravity = (player, game, input) ->
  if not player.sprite.body.blocked.down
    player.sprite.body.velocity.y += k.WorldGravity * game.time.physicsElapsed

airMovement = (player, game, input) ->
  # applyGravity player, game, input

  switch
    when input.keys.left.isDown
      player.sprite.body.velocity.x += -k.AirMoveFactor
      player.sprite.animations.play 'left'
    when input.keys.right.isDown
      player.sprite.body.velocity.x += k.AirMoveFactor
      player.sprite.animations.play 'right'
    else
      do player.sprite.animations.stop
      player.sprite.frame = 4


class Walk extends PlayerState
  name: 'WALK'

  accept: (player, game, input) ->
    walked = false
    for walkOn in player.walkableGroups
      game.physics.arcade.collide \
        player.sprite,
        walkOn,
        () -> walked = true
    # return walked
    return player.sprite.body.blocked.down

  enter: (player, game, data) ->

  exit: (player, game) ->

  update: (player, game, input) ->
    # nudge down to keep contact with floor
    # player.sprite.body.position.y += 1
    player.continueWalk game, input

    switch
      when input.keys.left.isDown
        v_ = player.sprite.body.velocity.x - k.MoveFactor
        if (Math.abs v_) < k.MaximumWalkSpeed
          player.sprite.body.velocity.x = v_
        player.sprite.animations.play 'left'
      when input.keys.right.isDown
        v_ = player.sprite.body.velocity.x + k.MoveFactor
        if (Math.abs v_) < k.MaximumWalkSpeed
          player.sprite.body.velocity.x = v_
        player.sprite.animations.play 'right'
      else
        do player.sprite.animations.stop
        player.sprite.frame = 4

    @checkAccepts player, game, input, [
      player._modes[modeCodes.GRAPPLE]
      player._modes[modeCodes.JUMP]
      player._modes[modeCodes.FALL]
      player._modes[modeCodes.GRIND]
      player._modes[modeCodes.FLY]
    ]


class Jump extends PlayerState
  name: 'JUMP'

  constructor: () ->
    @readyForNextJump = true

  accept: (player, game, input) ->
    (player.sprite.body.blocked.down and input.keys.jump.edge.down) ||
    ((not player.sprite.body.blocked.down) and @readyForNextJump and input.keys.jump.edge.down)

  enter: (player, game, data) ->
    player.sprite.body.velocity.y = -k.InitialJumpVelocity
    @timer = @startHighJumpCooldown player, game
    @willFall = false
    @applyInitialJumpForce player

    @_resetDoubleJumpCooldown player, game

  exit: (player, game) ->
    do @timer.stop
    do @timer.destroy

  update: (player, game, input) ->
    if @timer.ms < k.InitialJumpCooldownTime
      @applyInitialJumpForce player

      if not input.keys.jump.isDown
        @willFall = true
    else
      falling =
        @willFall or
        not input.keys.jump.isDown or
        @timer.ms > (k.HighJumpCooldownTime + k.InitialJumpCooldownTime)
      if falling
        player.setMode modeCodes.FALL
        return
      else
        @applyHighJumpForce player

    airMovement player, game, input

    @checkAccepts player, game, input, [
      player._modes[modeCodes.GRAPPLE]
      player._modes[modeCodes.GRIND]
      player._modes[modeCodes.WALK]
      player._modes[modeCodes.JUMP]
    ]

  applyInitialJumpForce: (player) ->
    player.sprite.body.velocity.y += -k.InitialJumpFactor

  applyHighJumpForce: (player) ->
    player.sprite.body.velocity.y -= k.HighJumpFactor

  startHighJumpCooldown: (player, game) ->
    cooldown = game.time.create false
    do cooldown.start
    return cooldown

  _resetDoubleJumpCooldown: (player, game) ->
    @readyForNextJump = false
    @doubleJumpCooldown = game.time.create true
    @doubleJumpCooldown.add k.DoubleJumpCooldownTime, () =>
      @readyForNextJump = true
    do @doubleJumpCooldown.start


class Fall extends PlayerState
  name: 'FALL'

  accept: (player, game, input) ->
    not player.sprite.body.blocked.down

  enter: (player, game, data) ->

  exit: (player, game) ->

  update: (player, game, input) ->
    airMovement player, game, input

    @checkAccepts player, game, input, [
      player._modes[modeCodes.GRAPPLE]
      player._modes[modeCodes.WALK]
      player._modes[modeCodes.GRIND]
      player._modes[modeCodes.JUMP]
    ]




class Grind extends PlayerState

  ### State fields

  canAccept
  cooldownTimer

  popped

  activeSegment
  previousSegment
  rail

  _localVelocity:
    forward
    balance
    isHeadedAlongRail
  ###

  name: 'GRIND'
  constructor: (player, game) ->
    @canAccept = true
    @cooldownTimer = game.time.create true
    @cooldownTimer.add 0, () =>
      @canAccept = false
    r = () =>
      @canAccept = true
      @cooldownTimer = game.time.create true
      @cooldownTimer.add 0, () =>
        @canAccept = false
      @cooldownTimer.add k.GrindCooldownTime, r
    @cooldownTimer.add k.GrindCooldownTime, r


  accept: (player, game, input, out_data) ->
    if not (@canAccept and input.keys.grind.isDown)
      # short-circuit so we don't need to check collisions
      return false

    ground = false
    onRail = null
    for grindOn in player.grindableGroups
      game.physics.arcade.collide \
        player.sprite,
        grindOn,
        ((player, railBlock) =>
          onRail =
            polyline: railBlock.railPolyline
            activeSegment: railBlock.railLineSegment
          ground = true)
    out_data.rail = onRail
    return ground


  # called when state is entered
  enter: (player, game, data) ->
    # @_balance = 0

    @_setActiveRail data.rail.polyline
    @activeSegment = data.rail.activeSegment
    game.debug.geom @activeSegment, 'rgba(255, 255, 0, 1)'
    @previousSegment = @activeSegment

    @_localVelocity =
      forward: Math.min player.sprite.body.speed, k.MaxGrindSpeed
      balance: 0      # just a velocity (pt/s); when going left-right, up is negative
      isHeadedAlongRail: (player.sprite.body.velocity.dot (@_lineToVector @activeSegment)) > 0

    pos = (_.pick player.sprite.body, 'x', 'y')
    {pt, segment} = @_closestPointOnLine pos, @rail.segments

    heading = @_lineToVector @activeSegment, negate: true

    @popped = _.pick player.sprite.body, 'friction'

    _.assign player.sprite.body,
      friction: 0


  # called when state is exited
  exit: (player, game) ->
    _.assign player.sprite.body, @popped
    do @cooldownTimer.start


  update: (player, game, input) ->
    # find active segment

    ## we can't go to a segment we've been to in the past
    remainingSegments = do =>
      t = []
      x = @activeSegment
      while x?
        t.push x
        x =
          if @_localVelocity.isHeadedAlongRail
          then @rail.next x
          else @rail.previous x
      return t
    for s in remainingSegments
      game.debug.geom s, 'rgba(0, 255, 0, 0.5)'

    {pt, segment} = @_closestPointOnLine player.sprite.body, remainingSegments
    # player.sprite.body.x = pt.x
    # player.sprite.body.y = pt.y
    game.debug.geom (new Phaser.Circle pt.x, pt.y, 20), 'rgba(255, 255, 0, 1)'

    if (Phaser.Point.distance pt, player.sprite.body) > 100
      player.setMode modeCodes.FALL
      return


    heading = @_lineToVector @activeSegment,
      normalize: true
      negate: not @_localVelocity.isHeadedAlongRail

    # deal with corners
    if @activeSegment isnt @previousSegment
      previousHeading = @_lineToVector @previousSegment,
        normalize: true
        negate: not @_localVelocity.isHeadedAlongRail
      # FIXME
      theta = @_angleBetween heading, previousHeading
      bendFactor = (-(Math.cos theta) + 1) / 2 # between 0 and 1
      @_localVelocity.forward +=
        k.BendAcceleration *
        bendFactor *
        @_localVelocity.balance *
        if (Math.sin theta) < 0 then 1 else -1
      @previousSegment = @activeSegment

    ###
    0 : [0, pi/2)
    1 : [pi/2, pi)
    2 : [pi, 3pi/2)
    3 : [3pi/2, 2pi)
    ###
    angle = (@activeSegment.angle + 2 * Math.PI) % (2 * Math.PI)
    quadrant = switch
      when 0 <= angle < (Math.PI / 2) then 0
      when (Math.PI / 2) <= angle < Math.PI then 1
      when Math.PI <= angle < (3 * Math.PI / 2) then 2
      when (3 * Math.PI / 2) <= angle < (2 * Math.PI) then 3
    negativeDown = do =>
      if @_localVelocity.isHeadedAlongRail and ((quadrant is 0) or (quadrant is 3))
        return input.keys.up.isDown
      if not @_localVelocity.isHeadedAlongRail and ((quadrant is 0) or (quadrant is 3))
        return input.keys.down.isDown
      if @_localVelocity.isHeadedAlongRail and not ((quadrant is 0) or (quadrant is 3))
        return input.keys.down.isDown
      if not @_localVelocity.isHeadedAlongRail and not ((quadrant is 0) or (quadrant is 3))
        return input.keys.up.isDown
    positiveDown = do =>
      if @_localVelocity.isHeadedAlongRail and ((quadrant is 0) or (quadrant is 3))
        return input.keys.down.isDown
      if not @_localVelocity.isHeadedAlongRail and ((quadrant is 0) or (quadrant is 3))
        return input.keys.up.isDown
      if @_localVelocity.isHeadedAlongRail and not ((quadrant is 0) or (quadrant is 3))
        return input.keys.up.isDown
      if not @_localVelocity.isHeadedAlongRail and not ((quadrant is 0) or (quadrant is 3))
        return input.keys.down.isDown

    # player balance control
    if negativeDown
      @_localVelocity.balance -= k.BalanceAcceleration
    if positiveDown
      @_localVelocity.balance += k.BalanceAcceleration

    # convert and assign velocity
    alignedVelocity = @_alignLocalVelocity @_localVelocity, heading
    player.sprite.body.velocity.set alignedVelocity.x, alignedVelocity.y

    switchMode = @checkAccepts player, game, input, [
      player._modes[modeCodes.GRAPPLE]
      player._modes[modeCodes.JUMP]
    ]


  _setActiveRail: (railPolyline) ->
    @rail = railPolyline

  _polylineLength: (polyline) ->
    _ polyline
      .pluck 'length'
      .reduce _.add


  _distanceToLengthRatio: (px, polyline) ->
    return px / @_polylineLength polyline


  _lengthRatioToDistance: (ratio, polyline) ->
    return ratio * @_polylineLength polyline


  # TODO: this can be cleverized
  _lineRatioToPoint: (amount, polyline) ->
    px = (@_polylineLength polyline) * amount

    if px < 0
      return null

    r = null
    for segment in polyline
      advanced = segment.length - px

      if advanced > 0
        heading =
          new Phaser.Point (Math.cos segment.angle), (Math.sin segment.angle)
        r =
          point: Phaser.Point.add segment.start, heading.setMagnitude px
          segment: segment
        break
      else
        px -= segment.length
        continue
    return r


  # TODO: also optimize
  # TODO: also, test
  ###
  return: `null` |
    {
      pt: Phaser.Point - the closest point to the input point on `segments`
      segment: Phaser.Line - the line segment that `pt` is on
    }
  ###
  _closestPointOnLine: ({x, y}, segments, game) ->
    distanceToFrom = (pt) -> Phaser.Point.distance pt, {x: x, y: y}

    pts = []
    for segment in segments
      heading = new Phaser.Line \
        x, y,
        x + segment.normalX * 1000,
        y + segment.normalY * 1000

      # DEBUG
      color = _ [segment.start.x, segment.end.x, segment.length]
        .map (n) -> n % 256
        .map Math.floor
        .value()
      colorCode = "rgba(#{color[0]}, #{color[1]}, #{color[2]}, 1)"
      game?.debug.geom heading, colorCode

      pt = Phaser.Line.intersects segment, heading, false

      pointOnLine = (line, x, y, allowance = 0) ->
        delta = ((x - line.start.x) * (line.end.y - line.start.y) - (line.end.x - line.start.x) * (y - line.start.y))
        delta < allowance
      pointOnSegment = (line, x, y, allowance = 0) ->
        xMin = Math.min line.start.x, line.end.x
        xMax = Math.max line.start.x, line.end.x
        yMin = Math.min line.start.y, line.end.y
        yMax = Math.max line.start.y, line.end.y
        (pointOnLine line, x, y, allowance) && (x >= xMin && x <= xMax) && (y >= yMin && y <= yMax)

      closestPt =
        if pointOnSegment segment, pt.x, pt.y, 0.01
        then pt
        else
          if (distanceToFrom segment.start) < (distanceToFrom segment.end)
          then segment.start
          else segment.end

      game?.debug.geom (new Phaser.Circle closestPt.x, closestPt.y, 20), colorCode

      pts.push
        pt: closestPt
        segment: segment
    if pts.length > 1
      return _ pts
        .map (pt) ->
          _.extend pt, distance: Phaser.Point.distance pt.pt, {x: x, y: y}
        .sortBy 'distance'
        .value()[0]
    else
      return pts[0]

  _nudgeBalance: (isLeft, deltaTime) ->
    console.log 'DEPRECATED: _nudgeBalance'
    # @_balance += k.BalanceNudgePower * (if isLeft then -1 else 1)

  _updateBalance: (player, game) ->
    console.log 'DEPRECATED: _updateBalance'
    # distance to closest point on active segment
    closest = @_closestPointOnLine player.sprite.body, [@activeSegment]
    if closest?
      offset = Phaser.Point.distance \
        closest.pt,
        (new Phaser.Point player.sprite.body.x, player.sprite.body.y)
      # @_balance *= 1 + offset * k.RailOffsetBalanceRatio * game.time.physicsElapsed


  _alignLocalVelocity: ({forward, balance, isHeadedAlongRail}, heading) ->
    localV = new Phaser.Point forward, balance
    # forwardVec = (new Phaser.Point (if isHeadedAlongRail then 1 else -1), 0)
    forwardVec = new Phaser.Point 1, 0

    angle = @_angleBetween \
      forwardVec,
      heading

    return Phaser.Point.rotate \
      localV,
      0,
      0,
      angle

  _lineToVector: (line, options = {}) ->
    _.defaults options,
      negate: false
      normalize: false
    r = Phaser.Point.subtract line.end, line.start
    if options.normalize
      Phaser.Point.normalize r, r
    if options.negate
      Phaser.Point.negative r, r
    return r

  # god, Phaser, get a vector library jeez
  _angleBetween: (from, to) ->
    angle = (Math.atan2 to.y, to.x) - (Math.atan2 from.y, from.x)
    if angle < 0
      angle += 2 * Math.PI
    return angle



class Grapple extends PlayerState
  name: 'GRAPPLE'

  constructor: (player, game, @grappleableGroups = []) ->
    @grappleSprite = game.add.sprite 0, 0, 'star'
    game.physics.arcade.enable @grappleSprite
    _.extend @grappleSprite.body, k.GrappleBodyProperties

    @_resetGrapple player, game

  accept: (player, game, input, out_data) ->
    if @grappleActive
      @_isMovingLeft player
      defaultGrappleVelocity =
        # if player.facing is Phaser.RIGHT
        if @_isMovingLeft player
        then Phaser.Point.multiply k.DefaultGrappleVelocity, (new Phaser.Point -1, 1)
        else k.DefaultGrappleVelocity

      @grappleSprite.body.velocity =
        Phaser.Point.add defaultGrappleVelocity, player.sprite.body.velocity

      if input.keys.grapple.edge.up
        @_resetGrapple player, game
        return false

      didGrapple = false
      for grappleOn in @grappleableGroups
        game.physics.arcade.collide @grappleSprite, grappleOn, () ->
          didGrapple = true
      return didGrapple
    else
      if input.keys.grapple.edge.down
        grappleTile = @_emitGrapple player, game
        if grappleTile?
          out_data.grappleTile = grappleTile
          return true
      return false

  # called when state is entered
  enter: (player, game, data) ->
    @grappleSprite.body.velocity = new Phaser.Point 0, 0
    @grappleSprite.body.x = data.grappleTile.worldX
    @grappleSprite.body.y = data.grappleTile.worldY

    @_isMovingClockwise = @_isMovingLeft player

    tangent = do =>
      if @_isMovingClockwise
        Phaser.Point.rperp \
          Phaser.Point.subtract \
            @grappleSprite.body.position,
            player.sprite.body.position
      else
        Phaser.Point.perp \
          Phaser.Point.subtract \
            @grappleSprite.body.position,
            player.sprite.body.position

    # idk what's up with `Phaser.Point.project` so...
    project = (a, ontoB) ->
      scalarProjection = (m, ontoN) -> m.dot (do ontoN.normalize)
      sp = scalarProjection a, ontoB
      (do ontoB.normalize).multiply sp, sp

    tangentVelocity = project \
      player.sprite.body.velocity,
      tangent

    @speed = do tangentVelocity.getMagnitude
    if @speed < k.MinGrappleSpeed
      @speed = k.MinGrappleSpeed
      tangentVelocity.setMagnitude @speed

    player.sprite.body.velocity = tangentVelocity

  # called when state is exited
  exit: (player, game) ->
    @_resetGrapple player, game

  update: (player, game, input) ->
    if input.keys.grapple.isDown
      # swing!
      tangent = do =>
        if @_isMovingClockwise
          Phaser.Point.rperp \
            Phaser.Point.subtract \
              @grappleSprite.body.position,
              player.sprite.body.position
        else
          Phaser.Point.perp \
            Phaser.Point.subtract \
              @grappleSprite.body.position,
              player.sprite.body.position

      tangent.setMagnitude @speed
      player.sprite.body.velocity = tangent
    else
      # let go!
      @_resetGrapple player, game
      player.setMode modeCodes.FALL

    modeSelect = @checkAccepts player, game, input, [
      player._modes[modeCodes.WALK]
      player._modes[modeCodes.GRIND]
    ]

    if not modeSelect?
      if player.sprite.body.blocked.left or player.sprite.body.blocked.right
        player.setMode modeCodes.FALL

  addGrappleable: (group) ->
    @grappleableGroups.push group

  _isMovingLeft: (player) -> player.sprite.body.velocity.x < 0

  _resetGrapple: (player, game) ->
    @grappleSprite.exists = false
    @grappleActive = false

  _emitGrapple: (player, game) ->
    grappleVelocity = do =>
      if @_isMovingLeft player
      then Phaser.Point.multiply k.DefaultGrappleVelocity, (new Phaser.Point -1, 1)
      else k.DefaultGrappleVelocity

    grappleRay = new Phaser.Line \
      player.sprite.body.x,
      player.sprite.body.y,
      player.sprite.body.x + grappleVelocity.x,
      player.sprite.body.y + grappleVelocity.y
    # game.debug.geom grappleRay, 'rgba(0, 255, 0, 1)'

    @grappleActive = true
    @grappleSprite.body.position = Phaser.Point.add \
      player.sprite.body.position,
      (Phaser.Point.normalize grappleVelocity).setMagnitude 10
    @grappleSprite.body.velocity = grappleVelocity
    @grappleSprite.exists = true

    grappleTile = _ player.grappleableGroups
      .map (grappleOn) -> grappleOn.getRayCastTiles? grappleRay, null, true
      .flatten()
      .map (tile) ->
        tilePosition = new Phaser.Point tile.worldX, tile.worldY

        tile: tile
        distance: Phaser.Point.distance tilePosition, player.sprite.body
      .sortBy 'distance'
      .pluck 'tile'
      .value()[0]

    return grappleTile



class Fly extends PlayerState
  name: 'FLY'

  # check if `player` accepts this mode and transitions
  # puts any data in `out_data`
  # returns true if accepted, else false
  accept: (player, game, input, out_data) ->
    out_data.previousMode = player.modeCode
    input.keys.fly.edge.down

  # called when state is entered
  enter: (player, game, data) ->
    player.sprite.body.velocity.set 0, 0
    @previousMode = data.previousMode
    player.sprite.body.allowGravity = false
    @wait = true
    setTimeout () => @wait = false

  # called when state is exited
  exit: (player, game) ->
    player.sprite.body.allowGravity = true

  update: (player, game, input) ->
    if input.keys.left.isDown
      player.sprite.body.position.x -= 300 * game.time.physicsElapsed
    if input.keys.right.isDown
      player.sprite.body.position.x += 300 * game.time.physicsElapsed
    if input.keys.up.isDown
      player.sprite.body.position.y -= 300 * game.time.physicsElapsed
    if input.keys.down.isDown
      player.sprite.body.position.y += 300 * game.time.physicsElapsed


    _closestPointOnLine = Grind.prototype._closestPointOnLine
    onRail = {}
    ground = false
    for grindOn in player.grindableGroups
      game.physics.arcade.collide \
        player.sprite,
        grindOn,
        ((player, railBlock) =>
          @onRail =
            polyline: railBlock.railPolyline
            activeSegment: railBlock.railLineSegment
          ground = true),
        ((player, railBlock) =>
          railBlock.railLineSegment isnt @onRail?.activeSegment)
      if ground
        break

    if @onRail
      closest = _closestPointOnLine player.sprite.body, @onRail.polyline.segments, game
      for segment in @onRail.polyline.segments
        game.debug.geom segment, 'rgba(255, 0, 0, 1)'
      if closest?
        game.debug.geom \
          (new Phaser.Circle closest.pt.x, closest.pt.y, 30),
          'rgba(0, 255, 0, 0.5)'
      else
        console.log 'no closest?'


    if (not @wait) and input.keys.fly.edge.down
      player.setMode @previousMode


module.exports =
  PlayerState: PlayerState
  Modes: [
    Walk
    Jump
    Fall
    Grind
    Grapple
    Fly
  ]

module.exports = _.extend module.exports, modeCodes