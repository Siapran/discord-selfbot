local discordia = require("discordia")
local fs = require('fs')

local concat = table.concat

local client = discordia.Client()

prefix = "::"
startingTime = os.date('!%Y-%m-%dT%H:%M:%S')
version = io.popen("git show-ref --head --abbrev --hash"):read()
hostname = io.popen("hostname"):read()



local commands = setmetatable({}, { __index = function( t, k )
	return { call = function( message, arg )
		log("Command unknown: " .. k)
		message:delete()
	end}
end})

-- courtesy of LazyShpee
local function load_module( file )
	local func, err = loadfile(file)
	if not func then
		log("Error loading module \"" .. file .. "\": " .. err)
		os.exit()
	end
	local cmds = {func(require)}
end

function commands.help( message, arg )
	if not arg then 
		local answer = { embed = {
			title = "Available commands",
			description = "`" .. concat(table.keys(commands), "`, `") .. "`"
		}}
		message:reply(answer)
	else
		local cmd = commands[arg]
		if cmd.name then
			local description = "**Synopsis**\n```\n"
				.. cmd.name .. " " .. cmd.synopsis .. "```\n"
				.. "**Description**\n```\n"
				.. cmd.description .. "```"
			local answer = { embed = {
				title = cmd.name,
				description = description
			}}
			message:reply(answer)
		end
	end
end

client:on("ready", function()
	log("Logged in as " .. client.user.username)
end)

client:on("resumed", function()
end)

client:on("messageCreate", function(message)
	if message.author ~= client.user then return end
	if not message.content:startswith(prefix) then return end
	log("Command: " .. message.content)
	local cmd, arg =
		message.content
		:sub(prefix:len() + 1)
		:match("(%S+)%s*(.*)")
	if cmd then
		commands[cmd].call(message, arg)
	end
end)

if args[2] then
	log("Starting bot with the following token:", args[2])
else
	log("Please provide a bot token via commandline arguments.")
	return
end

client:run(args[2])
args[2] = "TOKEN"
