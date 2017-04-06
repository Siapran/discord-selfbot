local concat = table.concat

local formats = {}
function formats.spaced( arg )
	local chars = arg:split()
	return concat(chars, " ")
end
function formats.juggalo( arg )
	local chars = arg:split()
	local upper = true
	for i,c in ipairs(chars) do
		if c:match("%a") then
			chars[i] = upper and c:upper() or c:lower()
			upper = not upper
		end
	end
	return concat(chars)
end
local emotes = {
	-- courtesy of LazyShpee
	lenny = '( ͡° ͜ʖ ͡°)',
	shrug = '¯\\_(ツ)_/¯',
}
function formats.emote( arg )
	return emotes[arg] or ""
end

local function format( message, arg )
	arg = arg:gsub("{{(.-)}}", function ( capture )
		local param, arg = capture:match("(%S+)%s*(.*)")
		return formats[param] and formats[param](arg) or arg
	end)
	message:reply(arg)
	message:delete()
end

return {
	name = "format",
	call = format,
	synopsis = "text",
	description = [[Format a text with simple substitutions.
Any occurence of:
	{{substitution_name text}}
will be formatted according to the named
substitution function.

Available substitutions:
	]] .. concat(table.keys(formats), "\n\t")
}
