local version = 20261012.1200
-- lib/Resume.lua
-- Shared resume-from-reboot pattern for long-running turtle programs.
--
-- Two halves:
--   1) Progress persistence: save a state table to a restore file
--      (periodically and after every move), reload it on boot.
--      Uses textutils.serialize; the state table must contain only
--      serializable values (numbers, strings, booleans, tables).
--   2) Boot resume: install/remove an auto-resume boot stub. The stub is
--      the extensionless "startup" file (NOT startup.lua), so it takes
--      boot precedence and the turtle resumes the program after a
--      reboot or chunk unload. A pre-existing startup file is backed up
--      and restored when the program finishes.
--
-- Pattern origin: civilwargeeky's Variable Size Quarry (global-env
-- snapshot + event replay) proved the concept; Daniel's long runners
-- (platformer, filler, cropper, cluster) converged on the simpler
-- state-table variant generalized here. The quarry itself is NOT
-- rewired to this library: its global-snapshot mechanism is load-bearing
-- and stays exactly as the author wrote it.

local Resume = {}

-- Save the state table to the restore file. Returns true on success.
function Resume.save(restoreFile, state)
    local f = fs.open(restoreFile, "w")
    if f then
        f.write(textutils.serialize(state))
        f.close()
        return true
    end
    return false
end

-- Load a previously saved state table. Returns the table, or nil when
-- no restore file exists or it cannot be deserialized.
function Resume.load(restoreFile)
    if fs.exists(restoreFile) then
        local f = fs.open(restoreFile, "r")
        if f then
            local data = textutils.unserialize(f.readAll())
            f.close()
            if data then
                return data
            end
        end
    end
    return nil
end

-- Delete the restore file if present.
function Resume.clear(restoreFile)
    if fs.exists(restoreFile) then
        fs.delete(restoreFile)
    end
end

-- Install the auto-resume boot stub.
--   marker:     unique comment line identifying our stub,
--               e.g. "-- Platformer Auto-Resume"
--   backupFile: where a pre-existing startup file is moved,
--               e.g. "startup_old_platformer"
-- The stub simply re-runs the currently running program on boot.
function Resume.installBootResume(marker, backupFile)
    local startupFile = "startup"
    if fs.exists(startupFile) then
        local f = fs.open(startupFile, "r")
        local content = f.readAll()
        f.close()
        if not content:find(marker, 1, true) then
            if fs.exists(backupFile) then fs.delete(backupFile) end
            fs.move(startupFile, backupFile)
        end
    end
    local f = fs.open(startupFile, "w")
    f.writeLine(marker)
    f.writeLine("shell.run(\"" .. shell.getRunningProgram() .. "\")")
    f.close()
end

-- Remove our boot stub and restore any backed-up startup file.
-- A backup that is itself one of our auto-resume stubs is treated as
-- stale and deleted instead of restored.
function Resume.removeBootResume(marker, backupFile)
    local startupFile = "startup"
    if fs.exists(backupFile) then
        local f = fs.open(backupFile, "r")
        local bContent = f.readAll() or ""
        f.close()
        if bContent:find(marker, 1, true) then
            fs.delete(backupFile)
        else
            if fs.exists(startupFile) then fs.delete(startupFile) end
            fs.move(backupFile, startupFile)
        end
    end
    if fs.exists(startupFile) then
        local f = fs.open(startupFile, "r")
        local content = f.readAll() or ""
        f.close()
        if content:find(marker, 1, true) then
            fs.delete(startupFile)
        end
    end
end

return Resume
