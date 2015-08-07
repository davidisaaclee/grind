k =
  BoostFactor: 3
  MoveFactor: 20
state = {}

startGrind = (obj, rail) ->
  state.info.dude.state = 'grinding'
  railInfo = state.info.rail

  # HACK: one-dimensional
  positionOnRail = (obj.body.position.x - railInfo.path.x[0]) / railInfo.path.length
  state.info.dude.grindInfo =
    progressRate: railInfo.path.length / obj.body.velocity.x
    rail: rail
    railInfo: railInfo
    velocity: obj.body.velocity.x
  state.info.dude.grindInfo.progress = positionOnRail

    # if state.info.dude.grindInfo.progressRate > 0
    # then 0
    # else 1

  console.log 'pr', state.info.dude.grindInfo.progressRate
  console.log "length: #{railInfo.path.length} vel: #{obj.body.velocity.x}"

canGrind = (obj, rail) ->
  (state.info.dude.state isnt 'grinding') and
    state.info.dude.canGrind and
    obj.body.velocity.x != 0

preload = (game) ->
  game.load.image('sky', 'assets/sky.png')
  game.load.image('ground', 'assets/platform.png')
  game.load.image('star', 'assets/star.png')
  game.load.spritesheet('dude', 'assets/dude.png', 32, 48)

create = (game) ->
  game.world.setBounds(0, 0, 1600, 1600)
  game.physics.startSystem Phaser.Physics.ARCADE
  game.time.advancedTiming = true

  platforms = game.add.group()
  platforms.enableBody = true

  rails = do game.add.group
  rails.enableBody = true

  groundLevel = game.world.height - 64

  ground = platforms.create(0, groundLevel, 'ground')
  ground.body.immovable = true
  ground.scale.setTo(8, 2)

  rail = rails.create 200, groundLevel - 128, 'ground'
  rail.body.immovable = true
  rail.scale.setTo(1, 0.5)

  player = game.add.sprite 32, game.world.height - 150, 'dude'
  player.info = {}
  game.physics.arcade.enable player
  player.body.bounce.y = 0.2
  player.body.gravity.y = 1000
  player.body.collideWorldBounds = true

  player.animations.add 'left', [0, 1, 2, 3], 10, true
  player.animations.add 'right', [5, 6, 7, 8], 10, true

  state =
    player: player
    info:
      dude:
        state: 'walking'
        canGrind: true
      rail:
        path:
          x: [ rail.left, rail.right ]
          y: [ rail.top ]
          length: rail.right - rail.left
    platforms: platforms
    rails: rails

  player.anchor.setTo 0.5, 0.5
  game.camera.follow player, Phaser.Camera.FOLLOW_PLATFORMER

update = (game) ->
  {player, platforms, rails} = state
  key = game.input.keyboard.addKeys
    'jump': Phaser.Keyboard.UP
    'down': Phaser.Keyboard.DOWN
    'left': Phaser.Keyboard.LEFT
    'right': Phaser.Keyboard.RIGHT
    'boost': Phaser.Keyboard.SHIFT
    'debug': Phaser.Keyboard.D
  startGrindCooldown = () ->
    state.info.dude.canGrind = false
    grindCooldown = game.time.create true
    grindCooldown.add 100, () ->
      state.info.dude.canGrind = true
      grindCooldown.stop true
    do grindCooldown.start

  if key.debug.isDown
    debugger

  game.physics.arcade.collide player, platforms

  if player.body.touching.down and state.info.dude.state is 'jumping'
    state.info.dude.state = 'walking'

  switch state.info.dude.state
    when 'walking', 'jumping'
      switch
        when key.left.isDown
          player.body.velocity.x += -k.MoveFactor
          player.info.facingLeft = true
          player.animations.play 'left'
        when key.right.isDown
          player.body.velocity.x += k.MoveFactor
          player.info.facingLeft = false
          player.animations.play 'right'
        else
          do player.animations.stop
          player.frame = 4
    when 'grinding'
      grindInfo = state.info.dude.grindInfo

      player.body.velocity.x = grindInfo.velocity
      player.body.velocity.y = 0
      grindInfo.progress += grindInfo.progressRate

      if (grindInfo.progress > 1) or (grindInfo.progress < 0)
        console.log grindInfo.progress
        console.log 'end of rail'
        state.info.dude.state = 'walking'
        do startGrindCooldown
      else
        position =
          x: game.math.linearInterpolation grindInfo.railInfo.path.x, grindInfo.progress
          y: game.math.linearInterpolation grindInfo.railInfo.path.y, grindInfo.progress
        player.body.position = position

  key.jump.onDown.add () ->
    if (state.info.dude.state is 'walking' || state.info.dude.state is 'grinding')
      state.info.dude.state = 'jumping'
      player.body.velocity.y = -600
      do startGrindCooldown

  if key.boost.isDown
    player.body.velocity.x *= k.BoostFactor

  game.physics.arcade.overlap player, rails, startGrind, canGrind, this

new Phaser.Game \
  800,
  600,
  Phaser.AUTO,
  '',
  preload: preload,
  create: create,
  update: update