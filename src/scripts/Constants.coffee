module.exports =
  WorldGravity: 2000

  # walking
  MaximumWalkSpeed: 500
  MoveFactor: 20

  # air
  AirMoveFactor: 5
  GravityConstant: 2000

  # jumping
  InitialJumpVelocity: 500
  InitialJumpFactor: 20
  HighJumpFactor: 20
  InitialJumpCooldownTime: 50
  HighJumpCooldownTime: 100

  # grinding
  GrindCooldownTime: 100

  PlayerBodyProperties:
    bounce:
      x: 0
      y: 0
    collideWorldBounds: true
    # drag: 1
    friction:
      x: 0.2
      y: 0.2
    # gravityScale: 1
    # maxSpeed: 999
    gravity:
      x: 0
      y: 0
    allowGravity: false

  MinGrappleSpeed: 500
  GrappleBodyProperties:
    allowGravity: false

  DefaultGrappleVelocity: new Phaser.Point 1500, -2000