local discordia = require("discordia")
local client = discordia.Client()

local levenshtein = string.levenshtein
local insert = table.insert
local concat = table.concat

local function log( ... )
	print(os.date("[%x %X]"), ...)
end

-- thanks SinisterRectus for this wonder
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

local startingTime = os.date('!%Y-%m-%dT%H:%M:%S')
local hostname = io.popen("hostname"):read()

local commands = setmetatable({}, { __index = function( t, k )
	return function( message, arg )
		log("Command unknown: " .. k)
		message:delete()
	end
end})

function commands.quote( message, arg )
	local target = message.channel:getMessage("id", arg)
	if not target then message.channel:loadMessages() end
	target = message.channel:getMessage("id", arg)
	if target then
		log("Found quote: " .. target.id)
		local answer = {embed = {
			description = target.content,
			author = {
				name = target.author.name,
				icon_url = target.author.avatarUrl
			},
		}}
		message:reply(answer)
	else
		log("Quote not found.")
	end
	message:delete()
end

local function printLine(...)
	local ret = {}
	for i = 1, select('#', ...) do
		local arg = tostring(select(i, ...))
		insert(ret, arg)
	end
	return concat(ret, '\t')
end

local pp = require('pretty-print')

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
	if not arg then return end -- make sure arg exists

	arg = arg:gsub('```%w*\n?', '') -- strip markdown codeblocks

	local lines = {}

	local sandbox = table.copy(_G) -- create a sandbox environment
	sandbox.message = msg
	sandbox.client = client

	sandbox.print = function(...) -- intercept printed lines with this
		insert(lines, printLine(...))
	end

	sandbox.p = function(...) -- intercept pretty-printed lines with this
		insert(lines, prettyLine(...))
	end

	local fn, syntaxError = load(arg, 'Exec', 't', sandbox)
	if not fn then return msg:reply(code(syntaxError)) end

	local success, runtimeError = pcall(fn)
	if not success then return msg:reply(code(runtimeError)) end

	if #lines == 0 then return end
	lines = concat(lines, '\n') -- bring all the lines together

	if #lines > 1990 then -- truncate long messages
		lines = lines:sub(1, 1990)
	end

	return msg:reply(code(lines)) -- and send them as a message reply
end

function commands.lua( message, arg )
	exec(arg, message)
end

function commands.cleanup( message, arg )
	message.channel:loadMessages()
	for msg in message.channel.messages do
		if message.author == msg.author then
			if msg.content:startswith("::lua") or msg.content:startswith("``") then
				msg:delete()
			end
		end
	end
	message:delete()
end

function commands.calc( message, arg )
	if not arg then return end -- make sure arg exists

	arg = "return (" .. arg .. ")"

	local sandbox = table.copy(math)

	local fn, syntaxError = load(arg, 'Calc', 't', sandbox)
	if not fn then return message:reply(code(syntaxError)) end

	local success, result = pcall(fn)
	if not success then return message:reply(code(result)) end

	return message:reply(code(tostring(result)))
end

client:on("ready", function()
	log("Logged in as " .. client.user.username)
end)

client:on("resumed", function()
end)

client:on("messageCreate", function(message)
	if message.author ~= client.user then return end
	if not message.content:startswith("::") then return end
	log("Command: " .. message.content)
	local cmd, arg = message.content:match('(%S+)%s+(.*)')
	cmd = cmd or message.content
	cmd = cmd:sub(3)

	commands[cmd](message, arg)
end)

if args[2] then
	log("Starting bot with the following token:", args[2])
else
	log("Please provide a bot token via commandline arguments.")
	return
end

client:run(args[2])
