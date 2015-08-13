_ = require 'lodash'

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


  mapLocation = k.System.AssetsDirectory + 'maps/longgrind.json'
  # mapLocation = k.System.AssetsDirectory + 'maps/grindground.json'
  # tilesLocation = k.System.AssetsDirectory + 'sprites/maps/map_tiles.png'
  tilesLocation = k.System.AssetsDirectory + 'sprites/maps/set2/tileset2.png'
  railTilesLocation = k.System.AssetsDirectory + 'sprites/maps/set2/rails.png'
  game.load.tilemap 'my-map', mapLocation, null, Phaser.Tilemap.TILED_JSON
  game.load.image 'my-tileset', tilesLocation
  game.load.image 'rail-tileset', railTilesLocation

create = (game) ->
  map = game.add.tilemap 'my-map'
  map.addTilesetImage 'tileset2', 'my-tileset'
  map.addTilesetImage 'rails_tileset', 'rail-tileset'

  blockLayer = map.createLayer 'ground'
  map.setCollision 10, true, blockLayer
  blockLayer.resizeWorld()

  railLayer = map.createLayer 'rails'

  grappleLayer = map.createLayer 'grapples'
  map.setCollisionByExclusion [], true, grappleLayer

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

  railLines = []
  for rail in map.objects['rail_lines']
    railPolyline = []
    for i in [0...(rail.polyline.length - 1)]
      if rail.polyline?
        [fromX, fromY] = rail.polyline[i]
        [toX, toY] = rail.polyline[i + 1]

        line = new Phaser.Line \
          fromX + rail.x,
          fromY + rail.y,
          toX + rail.x,
          toY + rail.y

        tiles = railLayer.getRayCastTiles line
        for tile in tiles
          tile.setCollision false, false, true, true
          tile.railLineSegment = line
          tile.railPolyline = railPolyline

        railPolyline.push line
        railLines.push line


  player = new Player \
    game,
    32,
    0,
    'dude',
    PlayerState.FALL,
    walkableGroups: [blockLayer]
    grindableGroups: [railLayer]
    grappleableGroups: [grappleLayer]

  _.assign state,
    players: [player]
    rails: rails
    platforms: platforms
    railLines: railLines
  input =
    keys: game.input.keyboard.addKeys
      'up': Phaser.Keyboard.UP
      'down': Phaser.Keyboard.DOWN
      'left': Phaser.Keyboard.LEFT
      'right': Phaser.Keyboard.RIGHT
      'boost': Phaser.Keyboard.SHIFT
      'debug': Phaser.Keyboard.D
      'jump': Phaser.Keyboard.SPACEBAR
      'grapple': Phaser.Keyboard.Z
      'grind': Phaser.Keyboard.X

  input.keys.jump = EdgeKey.fromKey input.keys.jump
  input.keys.grapple = EdgeKey.fromKey input.keys.grapple

  game.camera.follow player.sprite, Phaser.Camera.FOLLOW_PLATFORMER

previousInput = null

update = (game) ->
  {players, platforms, rails} = state
  {keys} = input

  for player in players
    player.update game, keys: keys

  if keys.debug.isDown
    debugger


new Phaser.Game \
  800,
  600,
  Phaser.AUTO,
  '',
  {preload: preload, create: create, update: update}