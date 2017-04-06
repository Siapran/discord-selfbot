local concat = table.concat

local function info( message, arg )
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
			text = concat(info, " | "),
		}
	end
	answer.embed.timestamp = startingTime
	message:reply(answer)
end

local function version( message, arg )
	local lines = {}
	local count = math.floor(tonumber(arg) or 6)
	for line in io.popen('git log --pretty=format:"%H %h %s" -n' .. count):lines() do
		local hash, abbrev, commit_msg = line:match("(%S+) (%S+) (.+)")
		insert(lines, ("**[%s](https://github.com/Siapran/discord-selfbot/commit/%s)**: %s"):format(abbrev, hash, commit_msg))
	end
	local answer = { embed = {
		title = "Version History",
		description = concat(lines, "\n"),
	}}
	message:reply(answer)
end

return {
	name = "info",
	call = info,
	synopsis = "",
	description = [[Display general information about this bot:
	title
	github repo
	host
	starting time]]
}, {
	name = "version",
	call = version,
	synopsis = "[count]",
	description = [[Display latest commits on the repo.
Defaults to 6 commits.]]
}
