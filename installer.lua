-- Master Turtle bootstrap installer.
-- Get it with:  pastebin get <code> installer
-- Then run:     installer
-- It detects your version, downloads the full updater from GitHub,
-- and runs it. HTTP must be enabled in your ComputerCraft config.

local BASE = "https://raw.githubusercontent.com/DaniCePe/Master-Turtle/main/"

local function detectTree()
  -- _HOST looks like "ComputerCraft 1.80pr1" (1.12.x) or
  -- "ComputerCraft 1.120.0" (1.20.x+). The 1.12.x tree targets 1.80.
  if (_HOST or ""):find("1.80") then return "1.12.x" end
  return "1.20.x"
end

print("Master Turtle installer")
local tree = detectTree()
print("Detected: " .. (_HOST or "?") .. " -> " .. tree .. " tree.")
io.write("Correct? [Y/n]: ")
local ans = (read() or ""):lower()
if ans ~= "" and ans ~= "y" and ans ~= "yes" then
  io.write("Which tree? [1] 1.12.x   [2] 1.20.x+: ")
  local c = read() or ""
  if c:sub(1, 1) == "1" then tree = "1.12.x" else tree = "1.20.x" end
end

print("Downloading updater (" .. tree .. ")...")
shell.run("wget", BASE .. tree .. "/updater.lua", "updater")
local h = fs.open("updater", "r")
if not h then
  print("Download failed. Is HTTP enabled in your ComputerCraft config?")
  return
end
h.close()
print("Running updater...")
shell.run("updater")
print("Done. Run 'updater' any time to update.")
