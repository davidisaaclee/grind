k = require 'Constants'
EdgeKey = require 'EdgeKey'
Player = require 'Player'
PlayerState = require 'PlayerState'

state = {}
input = {}

preload = (game) ->
  game.load.image 'sky', 'assets/sky.png'
  game.load.image 'ground', 'assets/platform.png'
  game.load.image 'star', 'assets/star.png'
  game.load.spritesheet 'dude', 'assets/dude.png', 32, 48

create = (game) ->
  game.world.setBounds 0, 0, 3200, 1600
  game.physics.startSystem Phaser.Physics.ARCADE
  game.physics.arcade.gravity.y = k.WorldGravity
  do game.physics.arcade.setBoundsToWorld

  platforms = do game.add.group
  platforms.enableBody = true
  rails = do game.add.group
  rails.enableBody = true
  grappleGroup = do game.add.group
  grappleGroup.enableBody = true

  groundLevel = game.world.height - 64

  ground = platforms.create 0, groundLevel, 'ground'
  ground.scale.setTo 8, 2
  game.physics.arcade.enable ground
  ground.body.immovable = true
  ground.body.allowGravity = false

  grable = grappleGroup.create 0, groundLevel - 400, 'ground'
  grable.scale.setTo 10, 0.5
  game.physics.arcade.enable grable
  grable.body.immovable = true
  grable.body.allowGravity = false

  for i in [1..8]
    rail = rails.create 400 * i, groundLevel - (64 * i), 'ground'
    rail.scale.setTo 1, 0.1
    game.physics.arcade.enable rail
    rail.body.immovable = true
    rail.body.allowGravity = false

  player = new Player \
    game,
    32,
    groundLevel - 64,
    'dude',
    PlayerState.FALL,
    walkableGroups: [platforms]
    grindableGroups: [rails]
    grappleableGroups: [grappleGroup]

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
      'jump': Phaser.Keyboard.SPACEBAR
      'grapple': Phaser.Keyboard.Z
      'grind': Phaser.Keyboard.X

  # ['jump', 'grapple'].forEach (key) ->
  #   input.keys[key] = EdgeKey.fromKey input.keys[key]
  input.keys.jump = EdgeKey.fromKey input.keys.jump
  input.keys.grapple = EdgeKey.fromKey input.keys.grapple

  game.camera.follow player.sprite, Phaser.Camera.FOLLOW_PLATFORMER

previousInput = null

update = (game) ->
  {players, platforms, rails} = state
  {keys} = input

  (player.update game, keys: keys) for player in players

  if keys.debug.isDown
    debugger


new Phaser.Game \
  800,
  600,
  Phaser.AUTO,
  '',
  preload: preload,
  create: create,
  update: update