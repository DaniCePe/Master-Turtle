local version = 20261013.1900
-- scenes/Dimensions.lua
-- Dimension prompt dialog: one row per dimension (label + textbox),
-- OK builds the command-line args and launches, Cancel goes back.
-- Enter moves between boxes; Enter on the last box triggers OK.

local Scene = require("lib.Scene")
local Label = require("lib.ui.Label")
local Button = require("lib.ui.Button")
local Textbox = require("lib.ui.Textbox")

local S = Scene:derive("dimensions")

function S:new(sceneMgr)
    S.super.new(self, sceneMgr)
    self.name = "Dimensions"
    self.boxes = {}
    self.focusIdx = 1
    self.btnClick = function(b) self:onBtnClick(b) end
    self.txtClick = function(t) self:onTxtClick(t) end
end

function S:enter(program)
    self.program = program
    self.boxes = {}
    self.focusIdx = 1
    self.em.entities = {}

    local W, H = _G.WIDTH, _G.HEIGHT
    local y = 3
    self.em:add(Label("lblDTitle", 1, 1, W, 1,
        program.name .. ": dimensions", colors.yellow, colors.black,
        "centre", "centre"), "lblDTitle")
    self.em:add(Label("lblDHint", 1, 2, W, 1,
        "Leave blank to be asked by the program",
        colors.lightGray, colors.black, "centre", "centre"), "lblDHint")

    for i, dim in ipairs(program.dims) do
        local numeric = dim.flag ~= "-mode" and dim.flag ~= "-inverted" and not dim.triple
        local lbl = Label("lblDim" .. i, 2, y, 26, 1,
            dim.label, colors.white, colors.black, "left", "centre")
        local box = Textbox("txtDim" .. i, 29, y, 12, 1,
            "", colors.white, colors.blue, "left", "centre", numeric, i)
        self.em:add(lbl, "lblDim" .. i)
        self.em:add(box, "txtDim" .. i)
        self.boxes[i] = { dim = dim, box = box }
        y = y + 1
    end

    self.lblErr = Label("lblDErr", 1, H - 3, W, 1,
        "", colors.red, colors.black, "left", "centre")
    self.em:add(self.lblErr, "lblDErr")

    self.btnOK = Button("btnDimOK", 2, H - 1, 10, 1,
        "OK", colors.black, colors.lime, "centre", "centre", 0, "", self.name)
    self.btnCancel = Button("btnDimCancel", W - 11, H - 1, 10, 1,
        "Cancel", colors.black, colors.gray, "centre", "centre", 0, "", self.name)
    self.em:add(self.btnOK, "btnDimOK")
    self.em:add(self.btnCancel, "btnDimCancel")

    S.super.enter(self)
    _G.events:hook("onBtnClick", self.btnClick)
    _G.events:hook("onTxtClick", self.txtClick)
    self:setFocus(1)
end

function S:exit()
    S.super.exit(self)
    _G.events:unhook("onBtnClick", self.btnClick)
    _G.events:unhook("onTxtClick", self.txtClick)
end

function S:setFocus(idx)
    if idx < 1 then idx = 1 end
    if idx > #self.boxes then idx = #self.boxes end
    self.focusIdx = idx
    for i, entry in ipairs(self.boxes) do
        entry.box:setFocus(i == idx)
    end
end

function S:onTxtClick(textbox)
    for i, entry in ipairs(self.boxes) do
        if entry.box == textbox then
            self:setFocus(i)
            break
        end
    end
end

function S:onBtnClick(button)
    if button.name == "btnDimCancel" then
        _G.sm:switch("Launcher")
    elseif button.name == "btnDimOK" then
        self:tryLaunch()
    end
end

function S:showError(msg)
    self.lblErr:setText(msg)
end

function S:clean(box)
    return (box.text or ""):gsub("%s+", "")
end

function S:tryLaunch()
    local args = {}
    for _, entry in ipairs(self.boxes) do
        local dim = entry.dim
        if dim.triple then
            -- quarry: one box holding "length width height"; keep spaces
            local nums = {}
            for n in (entry.box.text or ""):gmatch("%d+") do
                nums[#nums + 1] = math.floor(tonumber(n))
            end
            if #nums ~= 3 or nums[1] < 1 or nums[2] < 1 or nums[3] < 1 then
                return self:showError("Enter 3 positive numbers: length width height")
            end
            args[#args + 1] = dim.flag
            args[#args + 1] = tostring(nums[1])
            args[#args + 1] = tostring(nums[2])
            args[#args + 1] = tostring(nums[3])
        else
            local text = self:clean(entry.box)
            if text ~= "" then
                if dim.flag == "-inverted" then
                    local v = text:lower()
                    if v == "true" or v == "y" or v == "yes" or v == "1" then
                        args[#args + 1] = "-inverted"
                    elseif v ~= "false" and v ~= "n" and v ~= "no" and v ~= "0" then
                        return self:showError("Inverted: true or false")
                    end
                elseif dim.flag == "-mode" then
                    local v = text:lower()
                    if v ~= "floor" and v ~= "walls" and v ~= "solid"
                            and v ~= "hollow" and v ~= "roof" then
                        return self:showError("Mode: floor/walls/solid/hollow/roof")
                    end
                    args[#args + 1] = "-mode"
                    args[#args + 1] = v
                else
                    local n = math.floor(tonumber(text) or 0)
                    if n < 1 then
                        return self:showError("Enter a positive number: " .. dim.label)
                    end
                    args[#args + 1] = dim.flag
                    args[#args + 1] = tostring(n)
                end
            end
            -- blank = skip; the program itself will prompt for it
        end
    end
    _G.MasterTurtle.launch = { prog = self.program.prog, args = args }
    _G.sm:switch("Launcher")
end

function S:update(data)
    self.super.update(self, data)
    if data and data[1] == "key" and data[2] == keys.enter then
        if self.focusIdx < #self.boxes then
            self:setFocus(self.focusIdx + 1)
        else
            self:tryLaunch()
        end
    end
end

function S:draw()
    self.super.draw(self)
end

return S
