unitDef = {
  unitname            = "chickenc3c",
  name                = "Weevil",
  description         = "All-Terrain Swarmer",
  acceleration        = 1.25,
  bmcode              = "1",
  brakeRate           = 2,
  buildCostEnergy     = 5280,
  buildCostMetal      = 99,
  builder             = false,
  buildTime           = 1250,
  canAttack           = true,
  canGuard            = true,
  canMove             = true,
  canPatrol           = true,
  canstop             = "1",
  category            = "MOBILE WEAPON NOTAIR NOTSUB NOTSHIP ALL NOTHOVER SURFACE",
  corpse              = "DEAD",
  defaultmissiontype  = "Standby",
  explodeAs           = "BUG_DEATH",
  footprintX          = 2,
  footprintZ          = 2,
  iconType            = "chickenr",
  leaveTracks         = true,
  maneuverleashlength = "640",
  mass                = 89,
  maxDamage           = 920,
  turninplace         = 0,
  maxSlope            = 18,
  maxVelocity         = 3.2,
  maxreversevelocity  = 3,
  maxWaterDepth       = 15,
  movementClass       = "TKBOT2",
  noAutoFire          = false,
  noChaseCategory     = "VTOL",
  objectName          = "chickenc3c.s3o",
  seismicSignature    = 1,
  selfDestructAs      = "BIGBUG_DEATH",
  collisionVolumeType = "box",
  collisionVolumeOffsets = "0 -3 -3",
  collisionVolumeScales = "18 28 40",

  sfxtypes            = {

    explosiongenerators = {
      "custom:blood_spray",
      "custom:blood_explode",
      "custom:dirt",
    },

  },

  side                = "THUNDERBIRDS",
  sightDistance       = 370,
  smoothAnim          = true,
  sonarDistance       = 450,
  steeringmode        = "2",
  TEDClass            = "KBOT",
  trackOffset         = 0.5,
  trackStrength       = 9,
  trackStretch        = 1,
  trackType           = "ChickenTrackPointy",
  trackWidth          = 35,
  turnRate            = 900,
  upright             = false,
  workerTime          = 0,

  weapons             = {

    {
      def                = "WEAPON",
      mainDir            = "0 0 1",
      maxAngleDif        = 110,
    },

  },


  weaponDefs          = {

    WEAPON = {
      name                    = "Blob",
      areaOfEffect            = 120,
      craterBoost             = 0,
      craterMult              = 0,
      edgeeffectiveness       = 0.25,
      camerashake             = 0,

      damage                  = {      
        default=300,
		CHICKEN=10,
		TINYCHICKEN=10,  
      },

      endsmoke                = "0",
      explosionGenerator      = "custom:blood_explode_blue",
      impulseBoost            = 0.22,
      impulseFactor           = 0.22,
      intensity               = 0.7,
      interceptedByShieldType = 1,
      avoidFeature            = 0,
      lineOfSight             = true,
      noSelfDamage            = true,
      range                   = 245,
      reloadtime              = 3.6,
      renderType              = 4,
      rgbColor                = "0.3 0.5 0.6",
      size                    = 8,
      sizeDecay               = -0.3,
      soundhit                = "junohit2edit",
      accuracy				  = 512,
      startsmoke              = "0",
      tolerance               = 5000,
      targetmoveerror         = 0.4,
      turret                  = true,
      weaponTimer             = 0.5,
      weaponVelocity          = 200,
    },

  },


  featureDefs         = {

    DEAD = {
    },


    HEAP = {
    },

  },

}

return lowerkeys({ chickenc3c = unitDef })