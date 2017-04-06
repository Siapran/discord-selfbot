local insert = table.insert
local levenshtein = string.levenshtein

-- courtesy of Magicks
getmetatable("").__div = function(str, pattern)
	local matches = {}
	for match in str:gmatch(pattern) do
		insert(matches, match)
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
			return true
		end
		local currentPerm = chan:getPermissionOverwriteFor(member)
		if currentPerm.allowedPermissions:has(perm) then
			return true
		end
		if currentPerm.deniedPermissions:has(perm) then
			return false
		end
		for role in member.roles do
			currentPerm = chan:getPermissionOverwriteFor(role)
			if currentPerm.allowedPermissions:has(perm) then
				return true
			end
		end
		for role in member.roles do
			currentPerm = chan:getPermissionOverwriteFor(role)
			if currentPerm.deniedPermissions:has(perm) then
				return false
			end
		end
		currentPerm = chan:getPermissionOverwriteFor(chan.guild.defaultRole)
		if currentPerm.allowedPermissions:has(perm) then
			return true
		end
		if currentPerm.deniedPermissions:has(perm) then
			return false
		end
		for role in member.roles do
			currentPerm = role.permissions
			if currentPerm:has(perm) then
				return true
			end
		end
	end
	return false
end

local function code(str)
	return string.format('```\n%s```', str)
end