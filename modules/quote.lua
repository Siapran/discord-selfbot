local function quote( message, arg )
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
		local answer = { embed = {
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

return {
	name = "quote",
	call = quote,
	synopsis = "message_id [channel_id]",
	description = [[Quote a message from:
	the current channel (message_id)
	another channel (message_id channel_id)

You can get the IDs by going to:
	Settings > Appearance > Developper Mode
You will then be able to right click messages
and channels to get their ID.]]
}