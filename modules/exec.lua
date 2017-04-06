local timer = require("timer")
local pp = require('pretty-print')
local concat = table.concat

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

local function lua( message, arg )
	exec(arg, message)
end

local function calc( message, arg )
	if not arg then return end -- make sure arg exists

	arg = "return (" .. arg .. ")"

	local sandbox = setmetatable({}, {__index = math})

	local fn, syntaxError = load(arg, 'Calc', 't', sandbox)
	if not fn then return message:reply(code(syntaxError)) end

	local success, result = pcall(fn)
	if not success then return message:reply(code(result)) end

	return message:reply(code(tostring(result)))
end

return {
	name = "lua",
	call = lua,
	synopsis = "code",
	description = [[Execute the given code within a sandboxed environment.
Available sandboxed variables:
	]] .. concat({"message", "client", "timer", "print", "p"}, "\n\t")
}, {
	name = "calc",
	call = calc,
	synopsis = "expression",
	description = [[Evaluate the given expression with lua.
The math library is available.]]
}
