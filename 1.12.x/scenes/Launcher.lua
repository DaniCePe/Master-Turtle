local version = 20261013.1700
-- scenes/Launcher.lua
-- Master Turtle main menu: scrollable program list, Run/Quit.
-- Keyboard: up/down moves, Enter runs, Q quits. Mouse also works.

local Scene = require("lib.Scene")
local Label = require("lib.ui.Label")
local Button = require("lib.ui.Button")
local ListBox = require("lib.ui.ListBox")

local S = Scene:derive("launcher")

local function displayName(p)
    return p.name .. (p.loop and " [LOOP]" or "")
end

function S:new(sceneMgr)
    S.super.new(self, sceneMgr)
    self.name = "Launcher"

    -- program list, respecting gates (tk3 on 1.20.x only, cc-ai when installed)
    self.entries = {}
    local names = {}
    for _, p in ipairs(_G.MasterTurtle.programs) do
        if not p.gate or fs.exists(p.gate) then
            self.entries[#self.entries + 1] = p
            names[#names + 1] = displayName(p)
        end
    end

    local W, H = _G.WIDTH, _G.HEIGHT
    self.lblTitle = Label("lblTitle", 1, 1, W, 1,
        "MASTER TURTLE", colors.yellow, colors.black, "centre", "centre")
    self.lst = ListBox("lstProg", 2, 3, W - 3, H - 6,
        names, colors.white, colors.black, colors.gray)
    self.lblDesc = Label("lblDesc", 1, H - 2, W, 1,
        "", colors.lightGray, colors.black, "left", "centre")
    self.btnRun = Button("btnRun", 2, H - 1, 10, 1,
        "Run", colors.black, colors.lime, "centre", "centre", 0, "", self.name)
    self.btnInfo = Button("btnInfo", 21, H - 1, 10, 1,
        "Info", colors.white, colors.blue, "centre", "centre", 0, "", self.name)
    self.btnQuit = Button("btnQuit", W - 11, H - 1, 10, 1,
        "Quit", colors.black, colors.red, "centre", "centre", 0, "q", self.name)

    self.em:add(self.lblTitle, "lblTitle")
    self.em:add(self.lst, "lstProg")
    self.em:add(self.lblDesc, "lblDesc")
    self.em:add(self.btnRun, "btnRun")
    self.em:add(self.btnInfo, "btnInfo")
    self.em:add(self.btnQuit, "btnQuit")

    self.selIdx = 1
    self.btnClick = function(b) self:onBtnClick(b) end
    self.listClick = function(lb) self:onListClick(lb) end
end

function S:enter()
    S.super.enter(self)
    _G.events:hook("onBtnClick", self.btnClick)
    _G.events:hook("onListClick", self.listClick)
    self:setSelectedIndex(self.selIdx)
end

function S:exit()
    S.super.exit(self)
    _G.events:unhook("onBtnClick", self.btnClick)
    _G.events:unhook("onListClick", self.listClick)
end

function S:setSelectedIndex(idx)
    if idx < 1 then idx = 1 end
    if idx > #self.entries then idx = #self.entries end
    self.selIdx = idx
    local p = self.entries[idx]
    if p then
        self.lst.selectedText = displayName(p)
        self.lst:setHighlightRow(idx)
        local tag = p.loop and " [runs until stopped]" or ""
        self.lblDesc:setText(p.desc .. tag)
    end
end

function S:selectedEntry()
    return self.entries[self.selIdx]
end

function S:onListClick(lb)
    -- mouse selection: sync keyboard index to the clicked row
    local t = self.lst.selectedText
    for i, p in ipairs(self.entries) do
        if displayName(p) == t then
            self.selIdx = i
            break
        end
    end
    self:setSelectedIndex(self.selIdx)
end

function S:onBtnClick(button)
    if button.name == "btnQuit" then
        _G.MasterTurtle.quit = true
    elseif button.name == "btnRun" then
        self:runSelected()
    elseif button.name == "btnInfo" then
        self:showInfo()
    end
end

function S:showInfo()
    local p = self:selectedEntry()
    if not p then return end
    local W = _G.WIDTH
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.yellow)
    print(p.name)
    print("")
    term.setTextColor(colors.white)
    local text = p.desc .. (p.loop and " [runs until stopped]" or "")
    local line = ""
    for word in text:gmatch("%S+") do
        if #line + #word + 1 > W then
            print(line)
            line = word
        else
            line = line == "" and word or (line .. " " .. word)
        end
    end
    if line ~= "" then print(line) end
    print("")
    term.setTextColor(colors.lightGray)
    print("Press any key to return.")
    os.pullEvent("key")
end

function S:runSelected()
    local p = self:selectedEntry()
    if not p then return end
    if p.scene then
        _G.sm:switch(p.scene)
    elseif p.dims then
        _G.sm:switch("Dimensions", p)
    else
        _G.MasterTurtle.launch = { prog = p.prog, args = {}, info = p.info }
    end
end

function S:update(data)
    self.super.update(self, data)
    -- keyboard navigation for the list (turtles have no mouse)
    if data and data[1] == "key" then
        local key = data[2]
        if key == keys.up then
            self:setSelectedIndex(self.selIdx - 1)
        elseif key == keys.down then
            self:setSelectedIndex(self.selIdx + 1)
        elseif key == keys.enter then
            self:runSelected()
        elseif key == keys.i then
            self:showInfo()
        end
    end
end

function S:draw()
    self.super.draw(self)
end

return S
