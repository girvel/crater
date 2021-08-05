local g = require "_girvel"
local fnl = require "fnl"
local yaml = require "lyaml"
require "strong"

local http = require "socket.http"
local ltn12 = require "ltn12"

local sh = require "sh"
-- TODO dependencies
-- TODO .gitignore
-- TODO cd to root directory

local prompt, config, state

behaviour = {
	init=function()
		print(git("init"))

		config.set{
			name=prompt("project name", tostring(basename("$PWD"))),
			version=prompt("version", "0.1-0"),
			type=prompt("type (lua|love)"),
			platforms=prompt("platforms (github, luarocks)"):split("%s*,%s*") / g.set()
		}

		if config.platforms["github"] then
			
		end
	end
}

function prompt(query, default_value)
	io.write(query)

	if default_value then
		io.write(" [", default_value, "]")
	end
	print(":")

	io.write("  ")
	input = io.read()

	if input == "" and default_value then
		return default_value
	end

	return input
end

config = g.yaml_container()

-- TODO property container
state = setmetatable({
	
}, {
	__index=function(self, index)
		return self["get_" .. index](self)
	end,
	__newindex=function(self, index, value)
		return self["set_" .. index](self, value)
	end
})

behaviour[arg[1]](arg / g.slice(2) / g.unpack())