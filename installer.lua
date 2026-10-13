version = 20261013.0300
-- this script fetches "updater.lua" from the github repository
-- pastebin get piTvMqye installer
local filename = "updater.lua"
-- url masked so this account is not banned by Pastebin
-- From FAQ do not post spam links (this includes promoting your own site)
local base = "https:".."//".."raw.".."githubusercontent.".."com".."/DaniCePe".."/Master-Turtle".."/main/"

-- Detect version tree: "ComputerCraft 1.80pr1" -> 1.12.x, else 1.20.x
-- Prefer _MC_VERSION (e.g. "1.12.2"), since an unescaped dot in the
-- _HOST check never matched "ComputerCraft 1.89.2" (dan200 CC on 1.12.2).
local tree = "1.20.x"
local mc = _MC_VERSION or ""
if mc:find("^1%.12") or (_HOST or ""):find("1%.80") then tree = "1.12.x" end
print("Master Turtle installer")
print("Detected: " .. (_HOST or "?") .. " -> " .. tree .. " tree.")
io.write("Correct? [Y/n]: ")
local ans = (read() or ""):lower()
if ans ~= "" and ans ~= "y" and ans ~= "yes" then
	io.write("Which tree? [1] 1.12.x  [2] 1.20.x+: ")
	local c = read() or ""
	if c:sub(1, 1) == "1" then tree = "1.12.x" else tree = "1.20.x" end
end

local url = base .. tree .. "/" .. filename

-- Request download script from GitHub
local response, message = http.get(url)
if response == nil then
	error("Repository content request failed: " .. message)
end

local data = response.readAll()
response.close()

if data == nil then
	error("Download script not found!")
end

-- Write to updater.new first and validate it before touching the old
-- updater, so a truncated download never leaves no working updater.
if fs.exists("updater.new") then
	fs.delete("updater.new")
end

-- Try creating new file
local f = fs.open("updater.new", "w")
if f == nil then
	error("Could not open file!")
end

-- Save new file
f.write(data)
f.close()

assert(loadfile("updater.new"), "bad updater download")

-- Replace the old updater only after the download validated
if fs.exists(filename) then
	fs.delete(filename)
end
fs.move("updater.new", filename)

print("Running updater...")
-- Run download script
shell.run(filename:sub(0, -5))
