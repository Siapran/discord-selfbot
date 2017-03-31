local discordia = require("discordia")
local timer = require("timer")
local querystring = require("querystring")
local pp = require('pretty-print')

local levenshtein = string.levenshtein
local insert = table.insert
local concat = table.concat

local client = discordia.Client()

local prefix = "::"
local startingTime = os.date('!%Y-%m-%dT%H:%M:%S')
local version = io.popen("git show-ref --head --abbrev --hash"):read()
local hostname = io.popen("hostname"):read()

-- courtesy of Magicks
getmetatable("").__div = function(str, pattern)
	local matches = {}
	for match in str:gmatch(pattern) do
		table.insert(matches, match)
	end
	return matches
end

local function log( ... )
	print(os.date("[%x %X]"), ...)
end

-- courtesy of SinisterRectus
local function fuzzySearch(guild, arg)
	local member = guild:getMember('id', arg)
	if member then return member end

	local bestMember
	local bestDistance = math.huge
	local lowered = arg:lower()

	for m in guild.members do
		if m.nickname and m.nickname:lower():startswith(lowered, true) then
			local d = levenshtein(m.nickname, arg)
			if d == 0 then
				return m
			elseif d < bestDistance then
				bestMember = m
				bestDistance = d
			end
		end
		if m.username and m.username:lower():startswith(lowered, true) then
			local d = levenshtein(m.username, arg)
			if d == 0 then
				return m
			elseif d < bestDistance then
				bestMember = m
				bestDistance = d
			end
		end
	end

	return bestMember
end

local function hasUserPermissionForChannel( user, chan, perm )
	if chan.guild then
		local member = user:getMembership(chan.guild)
		if not member then return false end
		if member == chan.guild.owner then
			-- log("owner")
			return true
		end
		local currentPerm = chan:getPermissionOverwriteFor(member)
		if currentPerm.allowedPermissions:has(perm) then
			-- log("chan user override grant")
			return true
		end
		if currentPerm.deniedPermissions:has(perm) then
			-- log("chan user override deny")
			return false
		end
		for role in member.roles do
			currentPerm = chan:getPermissionOverwriteFor(role)
			if currentPerm.allowedPermissions:has(perm) then
				-- log("chan role override grant")
				return true
			end
		end
		for role in member.roles do
			currentPerm = chan:getPermissionOverwriteFor(role)
			if currentPerm.deniedPermissions:has(perm) then
				-- log("chan role override deny")
				return false
			end
		end
		currentPerm = chan:getPermissionOverwriteFor(chan.guild.defaultRole)
		if currentPerm.allowedPermissions:has(perm) then
			-- log("chan everyone override grant")
			return true
		end
		if currentPerm.deniedPermissions:has(perm) then
			-- log("chan everyone override deny")
			return false
		end
		for role in member.roles do
			currentPerm = role.permissions
			if currentPerm:has(perm) then
				-- log("user role grant")
				return true
			end
		end
	end
	return false
end

local function code(str)
	return string.format('```\n%s```', str)
end

local commands = setmetatable({}, { __index = function( t, k )
	return function( message, arg )
		log("Command unknown: " .. k)
		message:delete()
	end
end})

function commands.help( message, arg )
	local answer = {embed = {
		title = "Available commands",
		description = "`" .. table.concat(table.keys(commands), "`, `") .. "`"
	}}
	message:reply(answer)
end


function commands.quote( message, arg )
	local channel = message.channel
	local args = arg / "(%S+)"
	if #args > 1 then
		arg = args[1]
		channel = client:getChannel("id", args[2])
		if not channel then return message:delete() end
	end
	local target = channel:getMessage("id", arg)
	if not target then
		for msg in channel:getMessageHistoryAround({_id = arg}, 2) do
		    if msg.id == arg then
		    	target = msg
		    	break
		    end
		end
	end
	if target then
		log("Found quote: " .. target.id)
		local answer = {embed = {
			description = target.content,
			author = {
				name = target.member and target.member.name or target.author.name,
				icon_url = target.author.avatarUrl
			},
			timestamp = os.date('!%Y-%m-%dT%H:%M:%S', target.createdAt),
		}}

		if message.channel ~= channel then
			if message.guild ~= channel.guild then
				answer.embed.footer = {
					text = "On " .. channel.guild.name .. " | #" .. channel.name,
					icon_url = channel.guild.iconUrl,
				}
			else
				answer.embed.footer = {
					text = "On #" .. channel.name,
				}
			end
		end
		
		message:reply(answer)
	else
		log("Quote not found.")
	end
	return message:delete()
end

local function printLine(...)
	local ret = {}
	for i = 1, select('#', ...) do
		local arg = tostring(select(i, ...))
		insert(ret, arg)
	end
	return concat(ret, '\t')
end

local function prettyLine(...)
	local ret = {}
	for i = 1, select('#', ...) do
		local arg = pp.strip(pp.dump(select(i, ...)))
		insert(ret, arg)
	end
	return concat(ret, '\t')
end

-- courtesy of SinisterRectus
local function exec(arg, msg)
	if not arg then return end

	arg = arg:gsub('```%w*\n?', '')

	local lines = {}

	local sandbox = table.copy(_G)
	sandbox.message = msg
	sandbox.client = client
	sandbox.timer = timer
	sandbox.querystring = querystring

	sandbox.print = function(...)
		insert(lines, printLine(...))
	end

	sandbox.p = function(...)
		insert(lines, prettyLine(...))
	end

	local fn, syntaxError = load(arg, 'Exec', 't', sandbox)
	if not fn then return msg:reply(code(syntaxError)) end

	local success, runtimeError = pcall(fn)
	if not success then return msg:reply(code(runtimeError)) end

	if #lines == 0 then return msg:reply(code("Exec completed.")) end
	lines = concat(lines, '\n')

	if #lines > 1990 then
		lines = lines:sub(1, 1990)
	end

	return msg:reply(code(lines))
end

function commands.lua( message, arg )
	exec(arg, message)
end

function commands.cleanup( message, arg )
	message.channel:loadMessages()
	for msg in message.channel.messages do
		if message.author == msg.author then
			if msg.content:startswith(prefix) or msg.content:startswith("```") then
				msg:delete()
			end
		end
	end
end

function commands.calc( message, arg )
	if not arg then return end -- make sure arg exists

	arg = "return (" .. arg .. ")"

	local sandbox = setmetatable({}, {__index = math})

	local fn, syntaxError = load(arg, 'Calc', 't', sandbox)
	if not fn then return message:reply(code(syntaxError)) end

	local success, result = pcall(fn)
	if not success then return message:reply(code(result)) end

	return message:reply(code(tostring(result)))
end

function commands.tex( message, arg )
	if not arg then return end

	arg = arg:gsub('```%w*\n?', '')

	local tmpdir = io.popen("mktemp -d"):read()
	local texfile = io.open(tmpdir .. "/tex-output.tex", "w")
	texfile:write([[\documentclass[border=0.50001bp,varwidth=true]{standalone}
\begin{document}
]] .. arg .. [[
\end{document}
]])
	texfile:close()
	os.execute("cd " .. tmpdir .. " && pdflatex tex-output.tex && convert -density 300 tex-output.pdf -quality 90 -flatten tex-output.png")
	message:reply({file = tmpdir .. "/tex-output.png"})
	-- message:delete()
	-- todo: verify tmpdir and rm -rf
end

function commands.info( message, arg )
	local answer = { embed = {
		author = {
			name = message.author.name .. "'s selfbot",
			icon_url = client.user.avatarUrl,
		},
		description = "https://github.com/Siapran/discord-selfbot",

	}}
	if hostname or version then
		local info = {}
		insert(info, hostname and ("Running on " .. hostname))
		insert(info, version and ("Version " .. version))
		answer.embed.footer = {
			text = table.concat(info, " | "),
		}
	end
	answer.embed.timestamp = startingTime
	message:reply(answer)
end

function commands.version( message, arg )
	local lines = {}
	for line in io.popen('git log --pretty=format:"%H %h %s" -n6'):lines() do
		local hash, abbrev, commit_msg = line:match("(%S+) (%S+) (.+)")
		insert(lines, ("**[%s](https://github.com/Siapran/discord-selfbot/commit/%s)**: %s"):format(abbrev, hash, commit_msg))
	end
	local answer = { embed = {
		title = "Version History",
		description = table.concat(lines, "\n"),
	}}
	message:reply(answer)
end

function commands.lmgtfy( message, arg )
	message:reply("http://lmgtfy.com/?" .. querystring.stringify({q = arg}))
	message:delete()
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
	if(cmd) then
		commands[cmd](message, arg)
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
