local querystring = require("querystring")

local function cleanup( message, arg )
	message.channel:loadMessages()
	for msg in message.channel.messages do
		if message.author == msg.author then
			if msg.content:startswith(prefix) or msg.content:startswith("```") then
				msg:delete()
			end
		end
	end
end

local function lmgtfy( message, arg )
	message:reply("http://lmgtfy.com/?" .. querystring.stringify({q = arg}))
	message:delete()
end

return {
	name = "cleanup",
	call = cleanup,
	synopsis = "",
	description = [[Delete all cached messages starting with
"]] .. prefix .. [[" or code markdown.]])
}, {
	name = "lmgtfy",
	call = lmgtfy,
	synopsis = "search pattern",
	description = [[Quickly remind people how to google something.
Displays a link to lmgtfy with the provided search pattern.]]
}
