k = require 'Constants'
EdgeKey = require 'EdgeKey'
Player = require 'Player'

state = {}
input = {}

setPlayerMode = (mode) ->
  console.log 'mode: ', mode
  state.info.dude.state = mode

startGrind = (obj, rail) ->
  if not canGrind obj, rail
    return

  console.log 'grinding'
  obj.body.bounce.y = -1

  setPlayerMode 'grinding'
  railInfo = state.info.rail

  # HACK: one-dimensional
  positionOnRail = (obj.body.position.x - railInfo.path.x[0]) / railInfo.path.length
  state.info.dude.grindInfo =
    progressRate: railInfo.path.length / obj.body.velocity.x
    rail: rail
    railInfo: railInfo
    velocity: obj.body.velocity.x
  state.info.dude.grindInfo.progress = positionOnRail

canGrind = (obj, rail) ->
  (state.info.dude.state isnt 'grinding') and
    # state.info.dude.canGrind and
    obj.body.velocity.x != 0

preload = (game) ->
  game.load.image 'sky', 'assets/sky.png'
  game.load.image 'ground', 'assets/platform.png'
  game.load.image 'star', 'assets/star.png'
  game.load.spritesheet 'dude', 'assets/dude.png', 32, 48

create = (game) ->
  # game.world.setBounds 0, 0, 1600, 1600
  game.physics.startSystem Phaser.Physics.NINJA
  game.physics.ninja.gravity = 1
  do game.physics.ninja.setBoundsToWorld

  platforms = do game.add.group
  rails = do game.add.group

  groundLevel = game.world.height - 64

  ground = platforms.create 0, groundLevel, 'ground'
  ground.scale.setTo 8, 2
  game.physics.ninja.enable ground
  ground.body.immovable = true
  ground.body.gravityScale = 0

  rail = rails.create 200, groundLevel - 64, 'ground'
  rail.scale.setTo 1, 0.1
  game.physics.ninja.enable rail
  rail.body.immovable = true
  rail.body.gravityScale = 0

  player = new Player game, 32, game.world.height - 300, 'dude'
  player.addWalkable platforms
  player.addGrindable rails

  state =
    players: [player]
    rails: rails
    platforms: platforms
  input =
    keys: game.input.keyboard.addKeys
      'down': Phaser.Keyboard.DOWN
      'left': Phaser.Keyboard.LEFT
      'right': Phaser.Keyboard.RIGHT
      'boost': Phaser.Keyboard.SHIFT
      'debug': Phaser.Keyboard.D
      'jump': Phaser.Keyboard.UP

  input.keys.jump = EdgeKey.fromKey input.keys.jump

  # player.info = {}
  # game.physics.ninja.enable player
  # player.body.bounce.y = 0.2
  # player.body.gravityScale = 1
  # player.body.collideWorldBounds = true

  # player.animations.add 'left', [0, 1, 2, 3], 10, true
  # player.animations.add 'right', [5, 6, 7, 8], 10, true

  # state =
  #   player: player
  #   info:
  #     dude:
  #       state: 'walking'
  #       canGrind: true
  #     rail:
  #       path:
  #         x: [ rail.left, rail.right ]
  #         y: [ rail.top ]
  #         length: rail.right - rail.left
  #   platforms: platforms
  #   rails: rails

  # game.camera.follow player.sprite, Phaser.Camera.FOLLOW_PLATFORMER

previousInput = null

update = (game) ->
  {players, platforms, rails} = state
  {keys} = input

  (player.update game, keys: keys) for player in players

  if keys.debug.isDown
    debugger

  # startGrindCooldown = () ->
  #   # state.info.dude.canGrind = false
  #   grindCooldown = game.time.create true
  #   grindCooldown.add 100, () ->
  #     # state.info.dude.canGrind = true
  #     grindCooldown.stop true
  #   do grindCooldown.start

  # doesTheDudeGrind = () -> state.info.dude.state is 'grinding'
  # game.physics.ninja.collide player, platforms, () -> setPlayerMode 'walking'
  # game.physics.ninja.overlap player, rails, startGrind, null, this
  # game.physics.ninja.collide player, rails, startGrind, doesTheDudeGrind, this

  # if player.body.touching.down and state.info.dude.state is 'jumping'
  #   setPlayerMode 'walking'

  # switch state.info.dude.state
  #   when 'walking', 'jumping'
  #     switch
  #       when key.left.isDown
  #         player.body.velocity.x += -k.MoveFactor
  #         player.info.facingLeft = true
  #         player.animations.play 'left'
  #       when key.right.isDown
  #         player.body.velocity.x += k.MoveFactor
  #         player.info.facingLeft = false
  #         player.animations.play 'right'
  #       else
  #         do player.animations.stop
  #         player.frame = 4
  #   when 'grinding'
  #     grindInfo = state.info.dude.grindInfo

  #     player.body.velocity.x = grindInfo.velocity
  #     player.body.velocity.y = 0

  #     if not player.body.touching.down
  #       setPlayerMode 'jumping'


      # grindInfo.progress += grindInfo.progressRate

      # if (grindInfo.progress > 1) or (grindInfo.progress < 0)
      #   console.log grindInfo.progress
      #   console.log 'end of rail'
      #   setPlayerMode 'walking'
      #   do startGrindCooldown
      # else
      #   position =
      #     x: game.math.linearInterpolation grindInfo.railInfo.path.x, grindInfo.progress
      #     y: game.math.linearInterpolation grindInfo.railInfo.path.y, grindInfo.progress
      #   player.body.position = position

  # key.jump.onDown.add () ->
  #   if (state.info.dude.state is 'walking' || state.info.dude.state is 'grinding')
  #     setPlayerMode 'jumping'
  #     player.body.velocity.y = -600
  #     # do startGrindCooldown

  # if keys.boost.isDown
  #   player.body.velocity.x *= k.BoostFactor


new Phaser.Game \
  800,
  600,
  Phaser.AUTO,
  '',
  preload: preload,
  create: create,
  update: update