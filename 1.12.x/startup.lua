local version = 20261012.1200
-- Master Turtle startup.
-- Boots the Master Turtle launcher menu.
--
-- Quarry resume safety net: the quarry installs its own extensionless
-- "startup" resume stub while it runs (that file takes boot precedence).
-- If a quarry save exists but the stub is missing, offer the resume here
-- instead of dropping straight to the menu.
-- The other long runners (platformer, filler, cropper, cluster) manage
-- their own "startup" stubs the same way.

if fs.exists("Civil_Quarry_Restore") then
    print("Quarry save found.")
    print("Wait 5 seconds to resume it,")
    print("or press any key for the menu.")
    local timer = os.startTimer(5)
    local resume = true
    while true do
        local e = os.pullEvent()
        if e == "key" then
            resume = false
            break
        elseif e == "timer" then
            break
        end
    end
    if resume then
        print("Resuming quarry...")
        shell.run("quarry", "-resume")
        return
    end
end

shell.run("master")
