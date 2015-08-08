
###
Extends Phaser.Key to include edge events.
###
class EdgeKey extends Phaser.Key
  @fromKey: (phaserKey) ->
    phaserKey.edge =
      __state: if phaserKey.isDown then 'down' else 'up'
      down: false
      up: false

    phaserKey.update = () ->
      Phaser.Key.prototype.update.call phaserKey

      if (phaserKey.edge.__state is 'up') and phaserKey.isDown
        phaserKey.edge =
          __state: 'down'
          down: true
          up: false
      else if (phaserKey.edge.__state is 'down') and not phaserKey.isDown
        phaserKey.edge =
          __state: 'up'
          down: false
          up: true
      else
        phaserKey.edge.down = false
        phaserKey.edge.up = false

    return phaserKey

module.exports = EdgeKey