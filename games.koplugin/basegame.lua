local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local TextWidget = require("ui/widget/textwidget")
local Button = require("ui/widget/button")
local Widget = require("ui/widget/widget")
local Screen = Device.screen
local Size = require("ui/size")
local Font = require("ui/font")
local _ = require("gettext")
local logger = require("logger")

-- Custom game canvas widget
local GameCanvas = Widget:new{
    background = Blitbuffer.COLOR_BLACK,
}

function GameCanvas:init()
    self.dimen = Geom:new{
        w = self.width,
        h = self.height,
    }
end

function GameCanvas:paintTo(bb, x, y)
    if self.bb then
        bb:blitFrom(self.bb, x, y, 0, 0, self.width, self.height)
    end
end

local BaseGame = InputContainer:new{
    name = "basegame",
    modal = true,
    width = Screen:getWidth(),
    height = Screen:getHeight(),
    game_width = Screen:getWidth() - Size.margin.default * 4,
    game_height = Screen:getHeight() - Size.margin.default * 6,
    control_height = Size.item.height_large * 2,
}

function BaseGame:init()
    if Device:hasKeys() then
        self.key_events = {
            Back = {
                {"Back"},
                seqtext = "back",
                doc = "exit game"
            },
            -- Game-specific key events will be added by subclasses
        }
    end
    
    if Device:isTouchDevice() then
        self.ges_events = {
            -- Touch events will be added by subclasses
        }
    end
    
    self:setupGameArea()
    self:setupControls()
    self:createUI()
    
    -- Start game loop
    self.game_running = true
    self:startGameLoop()
end

function BaseGame:setupGameArea()
    -- Create game canvas
    self.canvas_width = self.game_width
    self.canvas_height = self.game_height - self.control_height
    
    self.canvas = GameCanvas:new{
        width = self.canvas_width,
        height = self.canvas_height,
        background = Blitbuffer.COLOR_BLACK,
    }
    
    -- Create the blitbuffer for the canvas
    self.canvas.bb = Blitbuffer.new(self.canvas_width, self.canvas_height, Blitbuffer.TYPE_BB8)
    self.canvas.bb:fill(Blitbuffer.COLOR_BLACK)
    
    -- Initialize game state - to be overridden by subclasses
    self:initGame()
end

function BaseGame:setupControls()
    -- Create control buttons - to be overridden by subclasses
    self.controls = HorizontalGroup:new{
        spacing = Size.spacing.default,
    }
    
    -- Common controls
    local pause_btn = Button:new{
        text = _("Pause"),
        callback = function()
            self:togglePause()
        end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local exit_btn = Button:new{
        text = _("Exit"),
        callback = function()
            self:exitGame()
        end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    table.insert(self.controls, pause_btn)
    table.insert(self.controls, exit_btn)
    
    -- Add game-specific controls
    self:addGameControls()
end

function BaseGame:createUI()
    local title = TextWidget:new{
        text = self.game_title or _("Game"),
        face = Font:getFace("tfont", 20),
        bold = true,
    }
    
    local game_container = VerticalGroup:new{
        spacing = Size.spacing.default,
        title,
        self.canvas,
        CenterContainer:new{
            dimen = Geom:new{
                w = self.game_width,
                h = self.control_height,
            },
            self.controls,
        }
    }
    
    local frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Size.border.window,
        margin = Size.margin.default,
        padding = Size.padding.default,
        game_container,
    }
    
    local container = CenterContainer:new{
        dimen = Geom:new{
            w = self.width,
            h = self.height,
        },
        frame,
    }
    
    self[1] = container
end

function BaseGame:startGameLoop()
    self.game_timer = UIManager:scheduleIn(self.tick_interval or 0.1, function()
        if self.game_running and not self.paused then
            self:updateGame()
            self:renderGame()
        end
        if self.game_running then
            self:startGameLoop()
        end
    end)
end

function BaseGame:togglePause()
    self.paused = not self.paused
end

function BaseGame:exitGame()
    self.game_running = false
    if self.game_timer then
        UIManager:unschedule(self.game_timer)
    end
    UIManager:close(self)
end

function BaseGame:onBack()
    self:exitGame()
    return true
end

function BaseGame:onCloseWidget()
    self.game_running = false
    if self.game_timer then
        UIManager:unschedule(self.game_timer)
    end
    UIManager:setDirty(nil, function()
        return "ui", self[1].dimen
    end)
end

-- Methods to be overridden by subclasses
function BaseGame:initGame()
    -- Initialize game-specific state
end

function BaseGame:addGameControls()
    -- Add game-specific control buttons
end

function BaseGame:updateGame()
    -- Update game logic
end

function BaseGame:renderGame()
    -- Render game to canvas
    UIManager:setDirty(self, function()
        return "ui", self.canvas.dimen
    end)
end

return BaseGame