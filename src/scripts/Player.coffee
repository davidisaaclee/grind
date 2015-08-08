_ = require 'lodash'
k = require 'Constants'
PlayerState = require 'PlayerState'

class Player
  constructor: (@game, x, y, spriteKey, mode = 0) ->
    @sprite = @game.add.sprite x, y, spriteKey
    @sprite.animations.add 'left', [0, 1, 2, 3], 10, true
    @sprite.animations.add 'right', [5, 6, 7, 8], 10, true

    @game.physics.ninja.enable @sprite
    _.assign @sprite.body, k.PlayerBodyProperties

    @_modes = (new State for State in PlayerState.Modes)
    @setMode mode

    @walkableGroups = []
    @grindableGroups = []

  update: (game, input) ->
    console.log @sprite.body.shape.velocity
    @mode.update this, game, input

  checkWalk: (game, input) ->
    for walkOn in @walkableGroups
      game.physics.ninja.collide \
        @sprite,
        walkOn,
        () => @setMode PlayerState.WALKING

  checkGrind: (game, input) ->
    for grindOn in @grindableGroups
      game.physics.ninja.overlap \
        @sprite,
        grindOn,
        (player, rail) => @setMode PlayerState.GRINDING, rail: rail
      # game.physics.ninja.collide @sprite, grindOn

  continueGrind: (game, input) ->
    for grindOn in @grindableGroups
      game.physics.ninja.collide @sprite, grindOn

  addWalkable: (group) -> @walkableGroups.push group

  addGrindable: (group) -> @grindableGroups.push group

  setMode: (stateCode, data) ->
    if @modeCode? and @modeCode is stateCode
      # same mode, do nothing
      return

    @mode?.exit this, @game
    newMode =
      if 0 <= stateCode < PlayerState.Modes.length
      then @_modes[stateCode]
      else console.log 'Invalid state code', stateCode; debugger
    console.log newMode.name
    if newMode?
      @mode = newMode
      @modeCode = stateCode
    @mode.enter this, @game, data


module.exports = Player