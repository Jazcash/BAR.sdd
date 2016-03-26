return {
	corshroud = {
		acceleration = 0,
		activatewhenbuilt = true,
		brakerate = 0,
		buildangle = 8192,
		buildcostenergy = 19524,
		buildcostmetal = 132,
		buildinggrounddecaldecayspeed = 30,
		buildinggrounddecalsizex = 4,
		buildinggrounddecalsizey = 4,
		buildinggrounddecaltype = "corshroud_aoplane.dds",
		buildpic = "CORSHROUD.DDS",
		buildtime = 9392,
		canattack = false,
		category = "ALL NOTLAND NOTSUB NOWEAPON NOTSHIP NOTAIR NOTHOVER SURFACE",
		collisionvolumeoffsets = "0 16 -2",
		collisionvolumescales = "34 93 34",
		collisionvolumetype = "CylY",
		corpse = "DEAD",
		description = "Long-Range Jammer",
		energyuse = 125,
		explodeas = "SMALL_BUILDINGEX",
		footprintx = 2,
		footprintz = 2,
		icontype = "building",
		idleautoheal = 5,
		idletime = 1800,
		maxdamage = 800,
		maxslope = 10,
		maxwaterdepth = 0,
		name = "Shroud",
		objectname = "CORSHROUD.s3o",
		onoffable = true,
		radardistancejam = 700,
		seismicsignature = 0,
		selfdestructas = "SMALL_BUILDING",
		sightdistance = 155,
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
				collisionvolumeoffsets = "-7.38106536865 2.64404296892e-05 2.18940734863",
				collisionvolumescales = "57.2317047119 61.2454528809 48.0499572754",
				collisionvolumetype = "Box",
				damage = 480,
				description = "Shroud Wreckage",
				energy = 0,
				featuredead = "HEAP",
				featurereclamate = "SMUDGE01",
				footprintx = 2,
				footprintz = 2,
				height = 20,
				hitdensity = 100,
				metal = 81,
				object = "CORSHROUD_DEAD.s3o",
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
				damage = 240,
				description = "Shroud Heap",
				energy = 0,
				featurereclamate = "SMUDGE01",
				footprintx = 2,
				footprintz = 2,
				height = 4,
				hitdensity = 100,
				metal = 32,
				object = "cor2x2a.s3o",
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
			canceldestruct = "cancel2",
			underattack = "warning1",
			cant = {
				[1] = "cantdo4",
			},
			count = {
				[1] = "count6",
				[2] = "count5",
				[3] = "count4",
				[4] = "count3",
				[5] = "count2",
				[6] = "count1",
			},
			ok = {
				[1] = "kbcormov",
			},
			select = {
				[1] = "radjam2",
			},
		},
	},
}
