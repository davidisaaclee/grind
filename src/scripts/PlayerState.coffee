k = require 'Constants'
_ = require 'lodash'

modeCodes =
  WALK: 0
  JUMP: 1
  FALL: 2
  GRIND: 3
  GRAPPLE: 4

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
    @_balance = 0
    @rail = data.rail.polyline
    @activeSegment = data.rail.activeSegment

    pos = (_.pick player.sprite.body, 'x', 'y')
    {pt, segment} = @_closestPointOnLine pos, @rail

    len = 0
    for s in @rail
      if s is segment
        len += Phaser.Point.distance s.start, pt
        break
      else
        len += s.length
    @progress = len / @_polylineLength @rail

    heading =
      new Phaser.Point \
        Math.cos @activeSegment.angle,
        Math.sin @activeSegment.angle
    @ratioVelocity = @_distanceToLengthRatio player.sprite.body.speed, @rail

    if (heading.dot player.sprite.body.velocity.normalize()) < 0
      @ratioVelocity *= -1

    @popped = _.pick player.sprite.body, 'friction'

    _.assign player.sprite.body,
      friction: 0
      velocity:
        x: 0
        y: 0


  # called when state is exited
  exit: (player, game) ->
    _.assign player.sprite.body, @popped
    heading = new Phaser.Point \
      Math.cos @activeSegment.angle,
      Math.sin @activeSegment.angle
    player.sprite.body.velocity =
      heading.setMagnitude (@_lengthRatioToDistance @ratioVelocity, @rail)
    do @cooldownTimer.start


  update: (player, game, input) ->
    @progress += @ratioVelocity * game.time.physicsElapsed

    result = @_lineRatioToPoint @progress, @rail
    if not result?
      player.setMode modeCodes.FALL
    else
      if input.keys.up.isDown
        @_nudgeBalance true, game.time.physicsElapsed
      else if input.keys.down.isDown
        @_nudgeBalance false, game.time.physicsElapsed

      {segment, point} = result
      @activeSegment = segment
      player.sprite.body.x = point.x
      player.sprite.body.y =
        point.y - player.sprite.body.halfHeight + (@_balance * k.BalanceSwayAmount)

      @_updateBalance player, game

      if not (-6 < @_balance < 6)
        player.setMode modeCodes.FALL
      else
        switchMode = @checkAccepts player, game, input, [
          player._modes[modeCodes.GRAPPLE]
          player._modes[modeCodes.JUMP]
        ]


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
  ###
  return: `null` |
    {
      pt: Phaser.Point - the closest point to the input point on `segments`
      segment: Phaser.Line - the line segment that `pt` is on
    }
  ###
  _closestPointOnLine: ({x, y}, segments) ->
    pts = []
    for segment in segments
      heading = new Phaser.Line \
        x, y,
        x + segment.normalX,
        y + segment.normalY
      pt = Phaser.Line.intersects segment, heading, false
      if pt?
        pts.push
          pt: pt
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
    @_balance += k.BalanceNudgePower * (if isLeft then -1 else 1)

  _updateBalance: (player, game) ->
    # distance to closest point on active segment
    closest = @_closestPointOnLine player.sprite.body, [@activeSegment]
    if closest?
      offset = Phaser.Point.distance \
        closest.pt,
        (new Phaser.Point player.sprite.body.x, player.sprite.body.y)
      @_balance *= 1 + offset * k.RailOffsetBalanceRatio * game.time.physicsElapsed
      console.log offset * k.RailOffsetBalanceRatio, offset



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

    # @_isMovingLeft player = @grappleSprite.body.x < player.sprite.body.x
    # @_isMovingLeft player = player.sprite.body.velocity.x < 0

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


module.exports =
  PlayerState: PlayerState
  Modes: [
    Walk
    Jump
    Fall
    Grind
    Grapple
  ]

module.exports = _.extend module.exports, modeCodes