local version = 20261012.1200
-- scenes/CCAI.lua
-- Launcher for the optional cc-ai chat client (RareMojo/cc-ai, MIT).
-- The button that reaches this scene is only listed when the "cc-ai"
-- program file exists; the scene itself degrades gracefully if not.

local Scene = require("lib.Scene")
local Label = require("lib.ui.Label")
local Button = require("lib.ui.Button")

local S = Scene:derive("ccai")

function S:new(sceneMgr)
    S.super.new(self, sceneMgr)
    self.name = "CCAI"

    local W, H = _G.WIDTH, _G.HEIGHT
    self.lblTitle = Label("lblCTitle", 1, 1, W, 1,
        "AI CHAT (cc-ai)", colors.yellow, colors.black, "centre", "centre")
    self.lblInfo1 = Label("lblCInfo1", 2, 3, W - 3, 1,
        "Chat with an AI from this turtle.", colors.white, colors.black,
        "left", "centre")
    self.lblInfo2 = Label("lblCInfo2", 2, 4, W - 3, 1,
        "Needs the cc-ai server running.", colors.lightGray, colors.black,
        "left", "centre")
    self.lblInfo3 = Label("lblCInfo3", 2, 5, W - 3, 1,
        "See optional/cc-ai/SERVER_SETUP.md", colors.lightGray, colors.black,
        "left", "centre")
    self.lblStatus = Label("lblCStatus", 2, 7, W - 3, 1,
        "", colors.orange, colors.black, "left", "centre")

    self.btnGo = Button("btnCGo", 2, H - 3, 16, 1,
        "Launch chat", colors.black, colors.lime, "centre", "centre",
        0, "", self.name)
    self.btnBack = Button("btnCBack", 2, H - 1, 16, 1,
        "Back", colors.black, colors.gray, "centre", "centre",
        0, "", self.name)

    self.em:add(self.lblTitle, "lblCTitle")
    self.em:add(self.lblInfo1, "lblCInfo1")
    self.em:add(self.lblInfo2, "lblCInfo2")
    self.em:add(self.lblInfo3, "lblCInfo3")
    self.em:add(self.lblStatus, "lblCStatus")
    self.em:add(self.btnGo, "btnCGo")
    self.em:add(self.btnBack, "btnCBack")

    self.btnClick = function(b) self:onBtnClick(b) end
end

function S:enter()
    S.super.enter(self)
    _G.events:hook("onBtnClick", self.btnClick)
    if fs.exists("cc-ai") then
        if fs.exists("cc-ai_config.txt") then
            self.lblStatus:setText("Client configured. Ready.")
        else
            self.lblStatus:setText("First run will walk you through setup.")
        end
        self.btnGo.isEnabled = true
    else
        self.lblStatus:setText("Module not installed.")
        self.btnGo.isEnabled = false
    end
end

function S:exit()
    S.super.exit(self)
    _G.events:unhook("onBtnClick", self.btnClick)
end

function S:onBtnClick(button)
    if button.name == "btnCBack" then
        _G.sm:switch("Launcher")
    elseif button.name == "btnCGo" and fs.exists("cc-ai") then
        -- run outside the event dispatch like other programs
        _G.MasterTurtle.launch = { prog = "cc-ai", args = {} }
        _G.sm:switch("Launcher")
    end
end

function S:update(data)
    self.super.update(self, data)
end

function S:draw()
    self.super.draw(self)
end

return S
