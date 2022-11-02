#!/usr/bin/env lua

-- Dynamic library based system check
local binaryFormat = package.cpath:match("%p[\\|/]?%p(%a+)")
if not binaryFormat == "so" then
	print("Only Linux is supported currently. Quitting...")
	os.exit(1)
end

VARS = {}

local function parseVariable(s)
	local k = ""
	local v = ""

	local lastindex = 1
	for i = 1, #s do
		local ch = s:sub(i, i)

		if ch == "=" then break end
		k = k .. ch
		lastindex = i
	end
	for i = lastindex + 2, #s do
		local ch = s:sub(i, i)
		v = v .. ch
	end

	VARS[k] = v
end

local function shellBegin(sh)
	if sh == "sh" or sh == "bash" then
		return "do"
	elseif sh == "fish" then
		return ""
	end
end

local function shellEnd(sh)
	if sh == "sh" or sh == "bash" then
		return "done"
	elseif sh == "fish" then
		return "end"
	end
end

local function shellArgv(sh)
	if sh == "sh" or sh == "bash" then
		return "@"
	elseif sh == "fish" then
		return "argv"
	end
end

local function shellAssign(sh, var, val)
	if sh == "sh" or sh == "bash" then
		return ("%s=%s"):format(var, val)
	elseif sh == "fish" then
		return ("set %s %s"):format(var, val)
	end
end

function printHelp()
	print("Pom - a shell based, C, binary-only build system")
	print("Usage: ./pom.lua var=val")
	print("\tpom.lua will create a build.sh file by reading $rules and provide the following env variables")
	print("\tCC (C compiler), RULES (its own filename), SHELL (the shell used), BINARY (the binary's name)")
	print("Variables:")
	print("\tcompiler - C compiler")
	print("\trules    - path to shell file containing functions to be executed")
	print("\tshell    - custom shell (default: sh)")
	print("\tname     - name of the binary")
	os.exit(0)
end

local function main()
	if #arg == 0 then
		printHelp()
	end

	-- Parse arguments
	for i = 1, #arg do
		local a = arg[i]

		if a == "help" then
			printHelp()
		elseif a:find("=") then
			parseVariable(a)
		end
	end

	-- Check variables
	if VARS["rules"] == nil then
		print("Rulesfile not set. Quitting...")
		os.exit(1)
	end
	if VARS["shell"] == nil then
		print("Custom shell not specified.")
		VARS["shell"] = "sh"
	end
	if VARS["compiler"] == nil then
		print("Compiler not set. build.sh will check for $CC or default to 'cc'")
	end
	if VARS["name"] == nil then
		print("Project name not set. Defaulting to bin")
	end

	local out = ""
	do
		-- Shebang
		out = out .. ("#!/usr/bin/env %s\n"):format(VARS["shell"])

		-- Compiler check
		if VARS["compiler"] == nil then
			out = out .. ("if [ -z ${CC+x} ]; then %s; fi\n"):format(shellAssign(VARS["shell"], "CC", "cc"))
		else
			out = out .. ("%s\n"):format(shellAssign(VARS["shell"], "CC", VARS["compiler"]))
		end

		-- Binary
		out = out .. ("%s\n"):format(shellAssign(VARS["shell"], "BIN", VARS["name"]))
		-- Rules
		out = out .. ("%s\n"):format(shellAssign(VARS["shell"], "RULES", VARS["rules"]))

		local rules = io.open(VARS["rules"], "r")
		if rules == nil then
			print("An error occurred while trying to read rules. Quitting...")
			os.exit(1)
		end
		out = out .. rules:read("a")

		out = out .. ("for rule in $%s ; %s \"$rule\" ; %s\n"):format(
			shellArgv(VARS["shell"]),
			shellBegin(VARS["shell"]),
			shellEnd(VARS["shell"]))
	end

	-- Finish
	local f = io.open("build.sh", "w")
	if f == nil then
		print("An error occurred while trying to write build.sh. Quitting...")
	end
	f:write(out)

	os.execute("chmod +x build.sh")

	print(("CC    = %s"):format(VARS["compiler"]))
	print(("BIN   = %s"):format(VARS["name"]))
	print(("SHELL = %s"):format(VARS["shell"]))
	print(("RULES = %s"):format(VARS["rules"]))
end

main()
