-- this script fetches "updater.lua" from the github repository
-- pastebin get piTvMqye installer
local filename = "updater.lua"
-- url masked so this account is not banned by Pastebin
-- From FAQ do not post spam links (this includes promoting your own site)
local base = "https:".."//".."raw.".."githubusercontent.".."com".."/DaniCePe".."/Master-Turtle".."/main/"

-- Detect version tree: "ComputerCraft 1.80pr1" -> 1.12.x, else 1.20.x
local tree = "1.20.x"
if (_HOST or ""):find("1.80") then tree = "1.12.x" end
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

-- Deleting existing file
if fs.exists(filename) then
	fs.delete(filename)
end

-- Try creating new file
local f = fs.open(filename, "w")
if f == nil then
	error("Could not open file!")
end

-- Save new file
f.write(data)
f.close()

print("Running updater...")
-- Run download script
shell.run(filename:sub(0, -5))
