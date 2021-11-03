fx_version "cerulean"
game "gta5"

author "InZidiuZ & Andyyy#7666"
description "Legacy Fuel"
version "1.4"

-- What to run
client_scripts {
	"config.lua",
	"functions.lua",
	"client.lua"
}

exports {
	"GetFuel", -- GetFuel(vehicle)
	"SetFuel" -- SetFuel(vehicle, fuel)
}
