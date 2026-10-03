--!strict
-- Lancement : lune run tests/run
local process = require("@lune/process")
local framework = require("./framework")

local specs = {
	require("./Kit.spec"),
	require("./Game.spec"),
}

if not framework.run(specs) then
	process.exit(1)
end
