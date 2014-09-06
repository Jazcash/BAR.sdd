function widget:GetInfo()
	return {
		name = "Extra Hotkeys",
		desc = "Adds hotkeys for buildings (Z,X,C,V), buildspacing (N,M), settarget (Y,J), resurrect (O)" ,
		author = "Beherith",
		date = "23 march 2012",
		license = "GNU LGPL, v2.1 or later",
		layer = 1,
		enabled = true
	}
end

local binds={
	"bind any+b buildspacing inc",
	"bind any+n buildspacing dec",
	"bind any+q controlunit",
	"bind z buildunit_armmex",
	"bind shift+z buildunit_armmex",
	"bind z buildunit_armamex",
	"bind shift+z buildunit_armamex",
	"bind z buildunit_cormex",
	"bind shift+z buildunit_cormex",
	"bind z buildunit_corexp",
	"bind shift+z buildunit_corexp",
	"bind z buildunit_armmoho",
	"bind shift+z buildunit_armmoho",
	"bind z buildunit_cormoho",
	"bind shift+z buildunit_cormoho",
	"bind z buildunit_cormexp",
	"bind shift+z buildunit_cormexp",
	"bind z buildunit_coruwmex",
	"bind shift+z buildunit_coruwmex",
	"bind z buildunit_armuwmex",
	"bind shift+z buildunit_armuwmex",
	"bind z buildunit_coruwmme",
	"bind shift+z buildunit_coruwmme",
	"bind z buildunit_armuwmme",
	"bind shift+z buildunit_armuwmme",
	"bind x buildunit_armsolar",
	"bind shift+x buildunit_armsolar",
	"bind x buildunit_armwin",
	"bind shift+x buildunit_armwin",
	"bind x buildunit_corsolar",
	"bind shift+x buildunit_corsolar",
	"bind x buildunit_corwin",
	"bind shift+x buildunit_corwin",
	"bind x buildunit_armadvsol",
	"bind shift+x buildunit_armadvsol",
	"bind x buildunit_coradvsol",
	"bind shift+x buildunit_coradvsol",
	"bind x buildunit_armfus",
	"bind shift+x buildunit_armfus",
	"bind x buildunit_armmmkr",
	"bind shift+x buildunit_armmmkr",
	"bind x buildunit_corfus",
	"bind shift+x buildunit_corfus",
	"bind x buildunit_cormmkr",
	"bind shift+x buildunit_cormmkr",
	"bind x buildunit_armtide",
	"bind shift+x buildunit_armtide",
	"bind x buildunit_cortide",
	"bind shift+x buildunit_cortide",
	"bind x buildunit_armuwfus",
	"bind shift+x buildunit_armuwfus",
	"bind x buildunit_coruwfus",
	"bind shift+x buildunit_coruwfus",
	"bind x buildunit_armuwmmm",
	"bind shift+x buildunit_armuwmmm",
	"bind x buildunit_coruwmmm",
	"bind shift+x buildunit_coruwmmm",
	"bind c buildunit_armllt",
	"bind shift+c buildunit_armllt",
	"bind c buildunit_armrad",
	"bind shift+c buildunit_armrad",
	"bind c buildunit_corllt",
	"bind shift+c buildunit_corllt",
	"bind c buildunit_corrad",
	"bind shift+c buildunit_corrad",
	"bind c buildunit_corrl",
	"bind shift+c buildunit_corrl",
	"bind c buildunit_armrl",
	"bind shift+c buildunit_armrl",
	"bind c buildunit_armpb",
	"bind shift+c buildunit_armpb",
	"bind c buildunit_armflak",
	"bind shift+c buildunit_armflak",
	"bind c buildunit_corvipe",
	"bind shift+c buildunit_corvipe",
	"bind c buildunit_corflak",
	"bind shift+c buildunit_corflak",
	"bind c buildunit_armtl",
	"bind shift+c buildunit_armtl",
	"bind c buildunit_cortl",
	"bind shift+c buildunit_cortl",
	"bind c buildunit_armsonar",
	"bind shift+c buildunit_armsonar",
	"bind c buildunit_corsonar",
	"bind shift+c buildunit_corsonar",
	"bind c buildunit_armfrad",
	"bind shift+c buildunit_armfrad",
	"bind c buildunit_corfrad",
	"bind shift+c buildunit_corfrad",
	"bind c buildunit_armfrt",
	"bind shift+c buildunit_armfrt",
	"bind c buildunit_corfrt",
	"bind shift+c buildunit_corfrt",
	"bind v buildunit_armnanotc",
	"bind shift+v buildunit_armnanotc",
	"bind v buildunit_armlab",
	"bind shift+v buildunit_armlab",
	"bind v buildunit_armvp",
	"bind shift+v buildunit_armvp",
	"bind v buildunit_cornanotc",
	"bind shift+v buildunit_cornanotc",
	"bind v buildunit_corlab",
	"bind shift+v buildunit_corlab",
	"bind v buildunit_corvp",
	"bind shift+v buildunit_corvp",
	"bind v buildunit_armsy",
	"bind shift+v buildunit_armsy",
	"bind v buildunit_corsy",
	"bind shift+v buildunit_corsy",
}
local unbinds={
	"bind any+c controlunit",
	"bind c controlunit",
	"bind Any+x  buildspacing dec",
	"bind x  buildspacing dec",
	"bindaction buildspacing dec",
	"bind any+z buildspacing inc",
	"bind z buildspacing inc",
	"bindaction buildspacing inc",

}
function widget:Initialize()
	for k,v in ipairs(unbinds) do
		Spring.SendCommands("un"..v)
	end
	for k,v in ipairs(binds) do
		Spring.SendCommands(v)
	end
    
	Spring.SendCommands("bind y settarget")
	Spring.SendCommands("bind j canceltarget")
    Spring.SendCommands("bind o resurrect")
end

function widget:Shutdown()
	for k,v in ipairs(binds) do
		Spring.SendCommands("un"..v)
	end
	for k,v in ipairs(unbinds) do
		Spring.SendCommands(v)
	end

    Spring.SendCommands("unbind y settarget")
	Spring.SendCommands("unbind j canceltarget")
    Spring.SendCommands("unbind o resurrect")
end