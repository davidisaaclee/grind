_ = require 'lodash'
k = require 'Constants'
PlayerState = require 'PlayerState'
# Grapple = require 'Grapple'

class Player
  constructor: (@game, x, y, spriteKey, mode = 0, options = {}) ->
    _.defaults options,
      walkableGroups: []
      grindableGroups: []
      grappleableGroups: []

    @sprite = @game.add.sprite x, y, spriteKey
    @sprite.animations.add 'left', [0, 1, 2, 3], 10, true
    @sprite.animations.add 'right', [5, 6, 7, 8], 10, true

    @game.physics.arcade.enable @sprite
    _.assign @sprite.body, k.PlayerBodyProperties

    @_modes = (new State this, @game for State in PlayerState.Modes)

    @_modes[PlayerState.GRAPPLE].addGrappleable options.grappleableGroups

    @setMode mode

    {@grindableGroups, @walkableGroups} = options

  update: (game, input) ->
    if not (input.keys.left.isDown and input.keys.right.isDown)
      if input.keys.left.isDown
        @facing = Phaser.LEFT
      else if input.keys.right.isDown
        @facing = Phaser.RIGHT
    @mode.update this, game, input

  continueWalk: (game, input) ->
    for walkOn in @walkableGroups
      game.physics.arcade.collide \
        @sprite,
        walkOn

  continueGrind: (game, input, rail) ->
    game.physics.arcade.collide @sprite, rail

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
    if newMode?
      console.log 'transitioning from', @mode?.name, ' to', newMode.name
      @mode = newMode
      @modeCode = stateCode
    else
      console.log 'idk what happen'
      debugger
    @mode.enter this, @game, data


module.exports = Player