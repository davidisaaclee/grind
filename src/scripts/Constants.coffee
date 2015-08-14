module.exports =
  System:
    AssetsDirectory: '../assets/'

  MapTileSideLength: 32

  WorldGravity: 2000

  # walking
  MaximumWalkSpeed: 200
  MoveFactor: 10

  # air
  AirMoveFactor: 4
  GravityConstant: 2000

  # jumping
  InitialJumpVelocity: 500
  InitialJumpFactor: 20
  HighJumpFactor: 20
  InitialJumpCooldownTime: 50
  HighJumpCooldownTime: 200
  DoubleJumpCooldownTime: 100

  # grinding
  GrindCooldownTime: 100
  BalanceAcceleration: 2
  MaxGrindSpeed: 300
  BendAcceleration: 10

  PlayerBodyProperties:
    bounce:
      x: 0
      y: 0
    collideWorldBounds: true
    friction:
      x: 0.2
      y: 0.2
    allowGravity: true

  MinGrappleSpeed: 500
  GrappleBodyProperties:
    allowGravity: false

  DefaultGrappleVelocity: new Phaser.Point 1500, -2000