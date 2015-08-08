k = require 'Constants'
_ = require 'lodash'

class PlayerState
  name: 'none'

  # called when state is entered
  enter: (player, game, data) ->

  # called when state is exited
  exit: (player, game) ->

  update: (player, game, input) ->
    console.log 'You need to override `update()`.'

modeCodes =
  WALKING: 0
  JUMPING: 1
  FALLING: 2
  GRINDING: 3

class Walking extends PlayerState
  name: 'walking'

  enter: (player, game, data) ->

  exit: (player, game) ->

  update: (player, game, input) ->
    switch
      when input.keys.left.isDown
        player.sprite.body.moveLeft k.MoveFactor
        player.sprite.animations.play 'left'
      when input.keys.right.isDown
        player.sprite.body.moveRight k.MoveFactor
        player.sprite.animations.play 'right'
      else
        do player.sprite.animations.stop
        player.sprite.frame = 4

    if input.keys.jump.edge.down
      player.setMode modeCodes.JUMPING

    player.checkGrind game, input
    player.checkWalk game, input

class Jumping extends PlayerState
  name: 'jumping'

  enter: (player, game, data) ->
    @timer = @startHighJumpCooldown player, game
    @applyInitialJumpForce player

  exit: (player, game) ->
    do @timer.stop

  update: (player, game, input) ->
    if input.keys.jump.isDown
    then @applyHighJumpForce player
    else player.setMode modeCodes.FALLING

    switch
      when input.keys.left.isDown
        player.sprite.body.moveLeft k.AirMoveFactor
        player.sprite.animations.play 'left'
      when input.keys.right.isDown
        player.sprite.body.moveRight k.AirMoveFactor
        player.sprite.animations.play 'right'
      else
        do player.sprite.animations.stop
        player.sprite.frame = 4

    player.checkGrind game, input
    player.checkWalk game, input

  applyInitialJumpForce: (player) ->
    player.sprite.body.moveUp k.InitialJumpFactor

  applyHighJumpForce: (player) ->
    player.sprite.body.moveUp k.HighJumpFactor

  startHighJumpCooldown: (player, game) ->
    cooldown = game.time.create true
    cooldown.add k.HighJumpCooldownTime, () =>
      player.setMode modeCodes.FALLING
    do cooldown.start
    return cooldown

class Falling extends PlayerState
  name: 'falling'

  enter: (player, game, data) ->

  exit: (player, game) ->

  update: (player, game, input) ->
    switch
      when input.keys.left.isDown
        player.sprite.body.moveLeft k.AirMoveFactor
        player.sprite.animations.play 'left'
      when input.keys.right.isDown
        player.sprite.body.moveRight k.AirMoveFactor
        player.sprite.animations.play 'right'
      else
        do player.sprite.animations.stop
        player.sprite.frame = 4

    player.checkGrind game, input
    player.checkWalk game, input

class Grinding extends PlayerState
  name: 'grinding'

  # called when state is entered
  enter: (player, game, data) ->
    @rail = data.rail

    if player.sprite.bottom > @rail.body.y
      player.sprite.body.y = @rail.body.y

    # bottomOffset = player.sprite.body.y - player.sprite.bottom
    # player.sprite.body.y = @rail.body.y + bottomOffset

    @popped = _.pick player.sprite.body, ['friction']
    _.assign player.sprite.body,
      friction: 0

  # called when state is exited
  exit: (player, game) ->
    _.assign player.sprite.body, @popped

  update: (player, game, input) ->
    if input.keys.jump.edge.down
      console.log 'grind -> jump'
      player.setMode modeCodes.JUMPING

    # player.checkGrind game, input
    player.continueGrind game, input

    # if not player.sprite.body.touching.down
    #   player.setMode modeCodes.FALLING

module.exports =
  PlayerState: PlayerState
  Modes: [
    Walking
    Jumping
    Falling
    Grinding
  ]

module.exports = _.extend module.exports, modeCodes