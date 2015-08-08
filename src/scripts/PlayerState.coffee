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


airMovement = (player, game, input) ->
  if not player.sprite.body.touching.down
    player.sprite.body.velocity.y += k.GravityConstant * game.time.physicsElapsed

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
        () => walked = true
    return walked

  enter: (player, game, data) ->

  exit: (player, game) ->

  update: (player, game, input) ->
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

    player.continueWalk game, input

    @checkAccepts player, game, input, [
      player._modes[modeCodes.GRAPPLE]
      player._modes[modeCodes.JUMP]
      player._modes[modeCodes.GRIND]
    ]


class Jump extends PlayerState
  name: 'JUMP'

  accept: (player, game, input) -> input.keys.jump.edge.down

  enter: (player, game, data) ->
    player.sprite.body.velocity.y = -k.InitialJumpVelocity
    @timer = @startHighJumpCooldown player, game
    @willFall = false
    @applyInitialJumpForce player

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
    ]

  applyInitialJumpForce: (player) ->
    player.sprite.body.velocity.y += -k.InitialJumpFactor

  applyHighJumpForce: (player) ->
    player.sprite.body.velocity.y -= k.HighJumpFactor

  startHighJumpCooldown: (player, game) ->
    cooldown = game.time.create false
    do cooldown.start
    return cooldown


class Fall extends PlayerState
  name: 'FALL'

  accept: (player, game, input) ->
    not player.sprite.body.touching.down

  enter: (player, game, data) ->

  exit: (player, game) ->

  update: (player, game, input) ->
    airMovement player, game, input

    @checkAccepts player, game, input, [
      player._modes[modeCodes.GRAPPLE]
      player._modes[modeCodes.WALK]
      player._modes[modeCodes.GRIND]
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
      game.physics.arcade.overlap \
        player.sprite,
        grindOn,
        (player, rail) =>
          onRail = rail
          ground = true
    out_data.rail = onRail
    return ground

  # called when state is entered
  enter: (player, game, data) ->
    @rail = data.rail

    player.sprite.body.velocity.y = 0

    @popped = _.pick player.sprite.body, 'friction'
    _.assign player.sprite.body,
      friction: 0

  # called when state is exited
  exit: (player, game) ->
    _.assign player.sprite.body, @popped
    do @cooldownTimer.start

  update: (player, game, input) ->
    player.continueGrind game, input, @rail

    counter = 0
    while (player.sprite.bottom > @rail.top) and counter < 5000
      counter++
      player.sprite.y -= player.sprite.bottom - @rail.top + 1

    switchMode = @checkAccepts player, game, input, [
      player._modes[modeCodes.GRAPPLE]
      player._modes[modeCodes.JUMP]
    ]

    if not switchMode?
      # check for ejection at ends of rail
      eject = player.sprite.body.x > @rail.right or
        player.sprite.body.x < @rail.left
      if eject
        player.setMode modeCodes.FALL


class Grapple extends PlayerState
  name: 'GRAPPLE'

  constructor: (player, game, @grappleableGroups = []) ->
    @grappleSprite = game.add.sprite 0, 0, 'star'
    game.physics.arcade.enable @grappleSprite
    _.extend @grappleSprite.body, k.GrappleBodyProperties

    @grappleSprite.exists = false
    @grappleActive = false

  accept: (player, game, input, out_data) ->
    if @grappleActive
      defaultGrappleVelocity =
        if player.facing is Phaser.RIGHT
        then k.DefaultGrappleVelocity
        else Phaser.Point.multiply k.DefaultGrappleVelocity, (new Phaser.Point -1, 1)

      @grappleSprite.body.velocity =
        Phaser.Point.add defaultGrappleVelocity, player.sprite.body.velocity

      if input.keys.grapple.edge.up
        @_resetGrapple player, game
        return false

      didGrapple = false
      for grappleOn in @grappleableGroups
        game.physics.arcade.overlap @grappleSprite, grappleOn, () ->
          didGrapple = true
      return didGrapple
    else
      if input.keys.grapple.edge.down
        @_emitGrapple player, game
      return false

  # called when state is entered
  enter: (player, game, data) ->
    @grappleSprite.body.velocity = new Phaser.Point 0, 0

    @clockwise = @grappleSprite.body.x < player.sprite.body.x

    tangent = do =>
      if @clockwise
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
        if @clockwise
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

    @checkAccepts player, game, input, [
      player._modes[modeCodes.WALK]
      player._modes[modeCodes.GRIND]
    ]

  addGrappleable: (group) ->
    @grappleableGroups.push group

  _resetGrapple: (player, game) ->
    @grappleSprite.exists = false
    @grappleActive = false

  _emitGrapple: (player, game) ->
    @grappleActive = true
    @grappleSprite.exists = true

    defaultGrappleVelocity =
      if player.facing is Phaser.RIGHT
      then k.DefaultGrappleVelocity
      else Phaser.Point.multiply k.DefaultGrappleVelocity, (new Phaser.Point -1, 1)

    @grappleSprite.body.position = Phaser.Point.add \
      player.sprite.body.position,
      (Phaser.Point.normalize defaultGrappleVelocity).setMagnitude 10
    @grappleSprite.body.velocity = defaultGrappleVelocity


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