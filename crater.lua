local fnl = require "fnl"
local tk = require "tk"
local yaml = require "lyaml"
local container = require "container"
require "strong"

local sh = require "sh"
-- TODO dependencies
-- TODO use root directory
-- TODO upload to luarocks
-- TODO rename 

local behaviour, prompt, config, keychain, state, rockspec, control

behaviour = {
	init=fnl.docs[[make current directory a crate]] .. function(self)
		print(git("init"))

		config:set_yaml{
			name=prompt("project name", tostring(basename("$PWD"))),
			version=prompt("version", "0.1-0"),
			build_systems=prompt("build systems (love, luarocks, dpkg)", "luarocks")
				:split("%s*,%s*") / tk.set()
		}

		gitignore:set(
			{".crater/build*", ".crater/source*"}
				/ fnl.separate("\n") 
				/ fnl.join()
		)

		if config.build_systems.luarocks then
			rockspec = container.file("%s.rockspec" % state.get_full_name())
			rockspec:set([[
package="%s"
version="%s"
source={
	url="%s",
	tag="%s"
}
description={
	summary="none",
	license="MIT"
}
build={
	type="builtin",
	modules={
		
	}
}
			]] % {config.name, config.version, config.git_origin, config.version})
		end

		if config.build_systems.dpkg then
			control:set([[
Package: %s
Version: %s
Section: custom
Prority: optional
Architecture: all
Essential: no
Installed-Size: 1024
Maintainer: girvel
Description: Launcher for a rock %s
			]] % {config.name, config.version, config.name})
		end
	end,
	
	commit=fnl.docs[[alias for git add, commit & push]] .. function(self, name)
		print(git("add ."))
		print(git('commit -m "%s"' % name))
		print(git('push origin master'))
	end,
	
	stat=fnl.docs[[show crate statistics]] .. function(self)
		print("crate", config.name)
		local content = find("./ -name '*.lua' -print0") : xargs("-0 cat")
		print("Lines:", content : wc("-l"))
		print("Words:", content : wc("-w"))
		print("Chars:", content : wc("-m"))
	end,
		
	build=fnl.docs[[builds]] .. function(self, type)
		type = type or "build"
		
		local index = ({major=1, minor=2, build=3})[type]
		local version = state.get_version()
		version[index] = version[index] + 1
		state.set_version(version)

		for build_type, _ in pairs(config.build_systems) do
			behaviour["build_" .. build_type](self)
		end
	end,

	build_dpkg=function(self)
		container.file(".crater/source-dpkg/usr/bin/" .. config.name):set(
			'#!/usr/bin/bash\nlua $(luarocks which %s | head -n 1) "$@"'
				% config.name
		)
		chmod("+x .crater/source-dpkg/usr/bin/" .. config.name)
		mkdir("-p .crater/source-dpkg/DEBIAN")
		cp("control", ".crater/source-dpkg/DEBIAN/")
		
		print(sh.command('dpkg-deb')("--build .crater/source-dpkg"))
		mkdir("-p .crater/build-dpkg")
		mv(
			".crater/source-dpkg.deb", 
			'.crater/build-dpkg/%s.deb' % state.get_full_name()
		)
		
		sudo("dpkg --install .crater/build-dpkg/%s.deb" % state.get_full_name())
	end,

	build_luarocks=function(self)
		print(luarocks("build --local"))
	end,

	build_love=function(self)
		print("Copying sources")
    mkdir("-p .crater/source-love")
    cp("-r ./* .crater/source-love")
    rm("-rf" ..
			{"documentation", ".git*", "README.md", ".crater", "eros/bin",
			 "*.exe", "*.love", "*.zip"}
			 	/ fnl.map[[" .crater/source-love/" .. it]]
			  / fnl.join()
    )

    print("Copying libraries")
    for _, l in ipairs(config.build_systems.love.dependencies) do
			print("- " .. l)
			cp(
				tostring(luarocks("which " .. l) : head("-n 1")) 
				.. " .crater/source-love/"
			)
    end

		print("Building love file")
    mkdir("-p .crater/build-love")
    cd(".crater/source-love; "
    .. "zip -9 -r ../build-love/%s.love . -q" % config.name)

    print("Creating exe file")
    cat(
    	"eros/bin/love.exe .crater/build-love/%s.love > .crater/build-love/%s.exe"
			% {config.name, config.name}  -- TODO fnl.fill
    )
    rm(".crater/build-love/*.love")

    print("Creating final zip archive")
    cp("eros/bin/*.dll .crater/build-love")
    mkdir("-p .crater/zip-love")
    cd(".crater/build-love; "
    .. "zip -9 -r ../zip-love/%s.zip . -q" % config.name)

    print("Finishing build")
	end,

	launch=function(self, ...)
		if not config.build_systems.love then
			print "Launch is supported only for love projects"
			return
		end

		os.execute(
			"love . " .. (
				{...} 
					/ fnl.map[['"%s"' % it]] 
					/ fnl.separate(" ") 
					/ fnl.join() or ""
			)
		)
	end,

	set_version=fnl.docs[[set version]] .. function(self, version)
		state.set_version(version:gsub("-", ".") / "." / fnl.map(tonumber))
	end,
	
	help=fnl.docs[[show help]] .. function(self)
		for name, f in pairs(behaviour) do
			if fnl.docs[f] then
				print(name, "-", fnl.docs[f])
			else
				print(name)
			end
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

config = container.yaml('.crater/config.yaml')
rockspec = container.file(tostring(ls('*.rockspec 2>/dev/null')))
control = container.file("control")
gitignore = container.file(".gitignore")

state = {
	get_version=function()
		return config.version:gsub("-", ".") / "." / fnl.map[[tonumber(it)]]
	end,
	set_version=function(value)
		local old_version = config.version
		config.version = "%s.%s-%s" % value

		if config.build_systems.luarocks then
			rockspec.path = "%s.rockspec" % state.get_full_name()
			mv("*.rockspec", rockspec.path)
			rockspec:set(rockspec:get()
				:gsub('version%s*=%s*"%S*"', 'version="%s"' % config.version)
				:gsub('tag%s*=%s*"%S*"', 'tag="%s"' % config.version)
			)
		end

		if config.build_systems.dpkg then
			control:set(control:get()
				:gsub('Version: %S*', 'Version: ' .. config.version)
			)
		end
	end,
	get_full_name=function()
		return config.name .. "-" .. config.version
	end
}

method = behaviour[arg[1]] or behaviour["help"]
method(behaviour, arg / fnl.slice(2) / fnl.unpack())
