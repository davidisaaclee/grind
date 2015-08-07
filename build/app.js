(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
var canGrind, create, k, preload, startGrind, state, update;

k = {
  BoostFactor: 3,
  MoveFactor: 20
};

state = {};

startGrind = function(obj, rail) {
  var positionOnRail, railInfo;
  state.info.dude.state = 'grinding';
  railInfo = state.info.rail;
  positionOnRail = (obj.body.position.x - railInfo.path.x[0]) / railInfo.path.length;
  state.info.dude.grindInfo = {
    progressRate: railInfo.path.length / obj.body.velocity.x,
    rail: rail,
    railInfo: railInfo,
    velocity: obj.body.velocity.x
  };
  state.info.dude.grindInfo.progress = positionOnRail;
  console.log('pr', state.info.dude.grindInfo.progressRate);
  return console.log("length: " + railInfo.path.length + " vel: " + obj.body.velocity.x);
};

canGrind = function(obj, rail) {
  return (state.info.dude.state !== 'grinding') && state.info.dude.canGrind && obj.body.velocity.x !== 0;
};

preload = function(game) {
  game.load.image('sky', 'assets/sky.png');
  game.load.image('ground', 'assets/platform.png');
  game.load.image('star', 'assets/star.png');
  return game.load.spritesheet('dude', 'assets/dude.png', 32, 48);
};

create = function(game) {
  var ground, groundLevel, platforms, player, rail, rails;
  game.world.setBounds(0, 0, 1600, 1600);
  game.physics.startSystem(Phaser.Physics.ARCADE);
  game.time.advancedTiming = true;
  platforms = game.add.group();
  platforms.enableBody = true;
  rails = game.add.group();
  rails.enableBody = true;
  groundLevel = game.world.height - 64;
  ground = platforms.create(0, groundLevel, 'ground');
  ground.body.immovable = true;
  ground.scale.setTo(8, 2);
  rail = rails.create(200, groundLevel - 128, 'ground');
  rail.body.immovable = true;
  rail.scale.setTo(1, 0.5);
  player = game.add.sprite(32, game.world.height - 150, 'dude');
  player.info = {};
  game.physics.arcade.enable(player);
  player.body.bounce.y = 0.2;
  player.body.gravity.y = 1000;
  player.body.collideWorldBounds = true;
  player.animations.add('left', [0, 1, 2, 3], 10, true);
  player.animations.add('right', [5, 6, 7, 8], 10, true);
  state = {
    player: player,
    info: {
      dude: {
        state: 'walking',
        canGrind: true
      },
      rail: {
        path: {
          x: [rail.left, rail.right],
          y: [rail.top],
          length: rail.right - rail.left
        }
      }
    },
    platforms: platforms,
    rails: rails
  };
  player.anchor.setTo(0.5, 0.5);
  return game.camera.follow(player, Phaser.Camera.FOLLOW_PLATFORMER);
};

update = function(game) {
  var grindInfo, key, platforms, player, position, rails, startGrindCooldown;
  player = state.player, platforms = state.platforms, rails = state.rails;
  key = game.input.keyboard.addKeys({
    'jump': Phaser.Keyboard.UP,
    'down': Phaser.Keyboard.DOWN,
    'left': Phaser.Keyboard.LEFT,
    'right': Phaser.Keyboard.RIGHT,
    'boost': Phaser.Keyboard.SHIFT,
    'debug': Phaser.Keyboard.D
  });
  startGrindCooldown = function() {
    var grindCooldown;
    state.info.dude.canGrind = false;
    grindCooldown = game.time.create(true);
    grindCooldown.add(100, function() {
      state.info.dude.canGrind = true;
      return grindCooldown.stop(true);
    });
    return grindCooldown.start();
  };
  if (key.debug.isDown) {
    debugger;
  }
  game.physics.arcade.collide(player, platforms);
  if (player.body.touching.down && state.info.dude.state === 'jumping') {
    state.info.dude.state = 'walking';
  }
  switch (state.info.dude.state) {
    case 'walking':
    case 'jumping':
      switch (false) {
        case !key.left.isDown:
          player.body.velocity.x += -k.MoveFactor;
          player.info.facingLeft = true;
          player.animations.play('left');
          break;
        case !key.right.isDown:
          player.body.velocity.x += k.MoveFactor;
          player.info.facingLeft = false;
          player.animations.play('right');
          break;
        default:
          player.animations.stop();
          player.frame = 4;
      }
      break;
    case 'grinding':
      grindInfo = state.info.dude.grindInfo;
      player.body.velocity.x = grindInfo.velocity;
      player.body.velocity.y = 0;
      grindInfo.progress += grindInfo.progressRate;
      if ((grindInfo.progress > 1) || (grindInfo.progress < 0)) {
        console.log(grindInfo.progress);
        console.log('end of rail');
        state.info.dude.state = 'walking';
        startGrindCooldown();
      } else {
        position = {
          x: game.math.linearInterpolation(grindInfo.railInfo.path.x, grindInfo.progress),
          y: game.math.linearInterpolation(grindInfo.railInfo.path.y, grindInfo.progress)
        };
        player.body.position = position;
      }
  }
  key.jump.onDown.add(function() {
    if (state.info.dude.state === 'walking' || state.info.dude.state === 'grinding') {
      state.info.dude.state = 'jumping';
      player.body.velocity.y = -600;
      return startGrindCooldown();
    }
  });
  if (key.boost.isDown) {
    player.body.velocity.x *= k.BoostFactor;
  }
  return game.physics.arcade.overlap(player, rails, startGrind, canGrind, this);
};

new Phaser.Game(800, 600, Phaser.AUTO, '', {
  preload: preload,
  create: create,
  update: update
});


},{}]},{},[1])


//# sourceMappingURL=app.js.map