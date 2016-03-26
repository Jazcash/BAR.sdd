return {
	corarad = {
		acceleration = 0,
		activatewhenbuilt = true,
		brakerate = 0,
		buildangle = 8192,
		buildcostenergy = 19115,
		buildcostmetal = 557,
		buildinggrounddecaldecayspeed = 30,
		buildinggrounddecalsizex = 4,
		buildinggrounddecalsizey = 4,
		buildinggrounddecaltype = "corarad_aoplane.dds",
		buildpic = "CORARAD.DDS",
		buildtime = 11960,
		canattack = false,
		category = "ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR NOTHOVER SURFACE",
		collisionvolumeoffsets = "0 40 0",
		collisionvolumescales = "35 98 35",
		collisionvolumetype = "CylY",
		corpse = "DEAD",
		description = "",
		energymake = 17,
		energyuse = 17,
		explodeas = "SMALL_BUILDINGEX",
		footprintx = 2,
		footprintz = 2,
		icontype = "building",
		idleautoheal = 5,
		idletime = 1800,
		losemitheight = 87,
		maxdamage = 330,
		maxslope = 10,
		maxwaterdepth = 0,
		name = "Advanced Radar Tower",
		objectname = "CORARAD.s3o",
		onoffable = true,
		radardistance = 3500,
		radaremitheight = 87,
		seismicsignature = 0,
		selfdestructas = "SMALL_BUILDING",
		sightdistance = 780,
		usebuildinggrounddecal = true,
		yardmap = "oooo",
		customparams = {
			faction = "core",
			normalmaps = "yes",
			normaltex = "unittextures/Core_normal.dds",
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "2.59153747559 -1.29760742169e-05 -1.5571975708",
				collisionvolumescales = "37.4503479004 89.5777740479 30.4736785889",
				collisionvolumetype = "Box",
				damage = 198,
				description = "Advanced Radar Tower Wreckage",
				energy = 0,
				featuredead = "HEAP",
				featurereclamate = "SMUDGE01",
				footprintx = 3,
				footprintz = 3,
				height = 20,
				hitdensity = 100,
				metal = 339,
				object = "CORARAD_DEAD.s3o",
				reclaimable = true,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "All Worlds",
				customparams = {
					faction = "core",
				},
			},
			heap = {
				blocking = false,
				category = "heaps",
				damage = 99,
				description = "Advanced Radar Tower Heap",
				energy = 0,
				featurereclamate = "SMUDGE01",
				footprintx = 3,
				footprintz = 3,
				height = 4,
				hitdensity = 100,
				metal = 136,
				object = "cor3x3c.s3o",
				reclaimable = true,
				resurrectable = 0,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "All Worlds",
				customparams = {
					faction = "core",
				},
			},
		},
		sounds = {
			activate = "radadvn2",
			canceldestruct = "cancel2",
			deactivate = "radadde2",
			underattack = "warning1",
			working = "radar2",
			count = {
				[1] = "count6",
				[2] = "count5",
				[3] = "count4",
				[4] = "count3",
				[5] = "count2",
				[6] = "count1",
			},
			select = {
				[1] = "radadvn2",
			},
		},
	},
}
