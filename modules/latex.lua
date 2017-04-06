local function tex( message, arg )
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

return {
	name = "tex",
	call = tex,
	synopsis = "tex code",
	description = [[Render a given LaTeX code to a picture and post it.]])
}