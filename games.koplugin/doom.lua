local parent_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
package.path = package.path .. ";" .. parent_dir .. "?.lua"
local BaseGame = require("basegame")
local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local Size = require("ui/size")
local Font = require("ui/font")
local RenderText = require("ui/rendertext")
local UIManager = require("ui/uimanager")
local InputDialog = require("ui/widget/inputdialog")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")
local logger = require("logger")
local util = require("util")

local DoomGame = BaseGame:new{
    game_title = _("Original Doom"),
    tick_interval = 0.1, -- Lower frequency for process management
    wad_file = nil,
    doom_process = nil,
    doom_executable = nil,
}

-- Doom port executables to try (in order of preference)
local DOOM_PORTS = {
    "chocolate-doom",
    "prboom-plus", 
    "crispy-doom",
    "gzdoom",
    "zdoom",
    "doom",
    "freedoom"
}

-- Standard Doom key mappings
local DOOM_KEYS = {
    forward = "Up",
    backward = "Down", 
    turn_left = "Left",
    turn_right = "Right",
    strafe_left = "comma",
    strafe_right = "period",
    fire = "ctrl",
    use = "space",
    run = "shift",
    weapon1 = "1",
    weapon2 = "2", 
    weapon3 = "3",
    weapon4 = "4",
    weapon5 = "5",
    weapon6 = "6",
    weapon7 = "7",
    map = "Tab",
    pause = "Escape"
}

function DoomGame:init()
    if not self.wad_file then
        logger.err("No WAD file specified")
        self:showError("No WAD file specified")
        return false
    end
    
    -- Find available Doom port
    self.doom_executable = self:findDoomPort()
    if not self.doom_executable then
        logger.err("No Doom port found on system")
        self:showDoomPortError()
        return false
    end
    
    logger.info("Using Doom port: " .. self.doom_executable)
    BaseGame.init(self)
    return true
end

function DoomGame:findDoomPort()
    for _, port in ipairs(DOOM_PORTS) do
        local cmd = "which " .. port .. " 2>/dev/null"
        local handle = io.popen(cmd)
        local result = handle:read("*a")
        handle:close()
        
        if result and result:match("^/") then
            return result:gsub("%s+", "") -- Remove whitespace
        end
    end
    return nil
end

function DoomGame:initGame()
    -- Initialize process state
    self.game_state = "starting"
    self.process_running = false
    self.key_pipe = nil
    
    -- Create temporary directory for Doom configuration
    self.temp_dir = "/tmp/koreader_doom_" .. os.time()
    os.execute("mkdir -p " .. self.temp_dir)
    
    -- Start Doom process
    if not self:startDoomProcess() then
        logger.err("Failed to start Doom process")
        self.game_state = "error"
        self:showError("Failed to start Doom process")
        return
    end
    
    self.game_state = "running"
end

function DoomGame:startDoomProcess()
    if not self.doom_executable then
        return false
    end
    
    -- Validate WAD file exists
    local wad_file = io.open(self.wad_file, "r")
    if not wad_file then
        self:showError("WAD file not found: " .. self.wad_file)
        return false
    end
    wad_file:close()
    
    -- Create Doom config file for proper settings
    self:createDoomConfig()
    
    -- Prepare Doom command line arguments
    local doom_args = {
        "-iwad", "\"" .. self.wad_file .. "\"",
        "-config", self.temp_dir .. "/doom.cfg",
        "-width", "800",
        "-height", "600",
        "-window", -- Run in windowed mode
        "-nomouse", -- Disable mouse to avoid conflicts
        "-nomusic", -- Disable music for e-ink devices
        "-nosound" -- Disable sound for e-ink devices
    }
    
    local cmd = self.doom_executable .. " " .. table.concat(doom_args, " ") .. " > /dev/null 2>&1 &"
    logger.info("Starting Doom with command: " .. cmd)
    
    -- Start the process
    local success = os.execute(cmd)
    if success then
        self.process_running = true
        -- Give the process time to start
        os.execute("sleep 3")
        
        -- Check if process actually started
        if self:checkProcessStatus() then
            logger.info("Doom process started successfully")
            return true
        else
            logger.err("Doom process failed to start")
            return false
        end
    end
    
    return false
end

function DoomGame:createDoomConfig()
    local config_path = self.temp_dir .. "/doom.cfg"
    local config_content = [[
# KOReader Doom Configuration
mouse_sensitivity 0
use_mouse 0
fullscreen 0
screen_width 800
screen_height 600
usegamma 0
]]
    
    local file = io.open(config_path, "w")
    if file then
        file:write(config_content)
        file:close()
    end
end

function DoomGame:addGameControls()
    -- Movement controls
    local forward_btn = Button:new{
        text = _("Forward"),
        callback = function() self:sendDoomKey(DOOM_KEYS.forward, true) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local backward_btn = Button:new{
        text = _("Back"),
        callback = function() self:sendDoomKey(DOOM_KEYS.backward, true) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local turn_left_btn = Button:new{
        text = _("Turn ◄"),
        callback = function() self:sendDoomKey(DOOM_KEYS.turn_left, true) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local turn_right_btn = Button:new{
        text = _("Turn ►"),
        callback = function() self:sendDoomKey(DOOM_KEYS.turn_right, true) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local strafe_left_btn = Button:new{
        text = _("Strafe ←"),
        callback = function() self:sendDoomKey(DOOM_KEYS.strafe_left, true) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local strafe_right_btn = Button:new{
        text = _("Strafe →"),
        callback = function() self:sendDoomKey(DOOM_KEYS.strafe_right, true) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    -- Action controls
    local fire_btn = Button:new{
        text = _("Fire"),
        callback = function() self:sendDoomKey(DOOM_KEYS.fire, true) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local use_btn = Button:new{
        text = _("Use"),
        callback = function() self:sendDoomKey(DOOM_KEYS.use, true) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local run_btn = Button:new{
        text = _("Run"),
        callback = function() self:sendDoomKey(DOOM_KEYS.run, true) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    -- Weapon selection
    local weapon1_btn = Button:new{
        text = _("Fist"),
        callback = function() self:sendDoomKey(DOOM_KEYS.weapon1, false) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local weapon2_btn = Button:new{
        text = _("Pistol"),
        callback = function() self:sendDoomKey(DOOM_KEYS.weapon2, false) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local weapon3_btn = Button:new{
        text = _("Shotgun"),
        callback = function() self:sendDoomKey(DOOM_KEYS.weapon3, false) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local map_btn = Button:new{
        text = _("Map"),
        callback = function() self:sendDoomKey(DOOM_KEYS.map, false) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    -- Add all controls
    table.insert(self.controls, forward_btn)
    table.insert(self.controls, backward_btn)
    table.insert(self.controls, turn_left_btn)
    table.insert(self.controls, turn_right_btn)
    table.insert(self.controls, strafe_left_btn)
    table.insert(self.controls, strafe_right_btn)
    table.insert(self.controls, fire_btn)
    table.insert(self.controls, use_btn)
    table.insert(self.controls, run_btn)
    table.insert(self.controls, weapon1_btn)
    table.insert(self.controls, weapon2_btn)
    table.insert(self.controls, weapon3_btn)
    table.insert(self.controls, map_btn)
end

function DoomGame:sendDoomKey(key, hold)
    if not self.process_running then
        return
    end
    
    -- Check if xdotool is available
    local xdotool_check = os.execute("which xdotool > /dev/null 2>&1")
    if not xdotool_check then
        -- Fallback: Try to find the window using wmctrl
        self:sendKeyFallback(key, hold)
        return
    end
    
    -- Use xdotool to send keys to the Doom window
    local window_cmd = "xdotool search --class doom"
    local window_handle = io.popen(window_cmd)
    local window_id = window_handle:read("*a")
    window_handle:close()
    
    if window_id and window_id ~= "" then
        window_id = window_id:gsub("%s+", "")
        local key_cmd
        
        if hold then
            -- Send key press and release quickly
            key_cmd = string.format("xdotool windowfocus %s keydown %s; sleep 0.1; xdotool keyup %s", 
                                  window_id, key, key)
        else
            -- Single key press
            key_cmd = string.format("xdotool windowfocus %s key %s", window_id, key)
        end
        
        os.execute(key_cmd .. " > /dev/null 2>&1 &")
    end
end

function DoomGame:sendKeyFallback(key, hold)
    -- Alternative method without xdotool - may not work on all systems
    local key_cmd = string.format("echo '%s' > /proc/self/fd/1", key)
    os.execute(key_cmd .. " > /dev/null 2>&1")
end

function DoomGame:updateGame()
    if not self.process_running then
        return
    end
    
    -- Check if Doom process is still running
    if not self:checkProcessStatus() then
        self.game_state = "stopped"
        logger.info("Doom process has ended")
    end
end

function DoomGame:checkProcessStatus()
    if not self.process_running then
        return false
    end
    
    -- Check if process is still running
    local check_cmd = "pgrep -f 'doom.*" .. self.wad_file:match("([^/]+)$") .. "'"
    local handle = io.popen(check_cmd)
    local result = handle:read("*a")
    handle:close()
    
    if result and not result:match("^%s*$") then
        return true
    else
        self.process_running = false
        return false
    end
end

function DoomGame:renderGame()
    self.canvas.bb:fill(Blitbuffer.COLOR_WHITE)
    
    if self.game_state == "starting" then
        self:drawCenteredText("Starting Original Doom...", self.canvas_height / 2 - 60)
        self:drawCenteredText("Please wait for the game window to appear", self.canvas_height / 2 - 20)
        self:drawCenteredText("This may take a few seconds", self.canvas_height / 2 + 20)
        
    elseif self.game_state == "running" then
        self:drawCenteredText("Original Doom is Running", 60)
        self:drawCenteredText("The game is running in a separate window", 100)
        self:drawCenteredText("Use the controls below to play", 140)
        self:drawCenteredText("WAD: " .. (self.wad_file:match("([^/]+)$") or "Unknown"), 180)
        
        -- Add helpful instructions
        self:drawCenteredText("Instructions:", 240)
        self:drawCenteredText("• Use movement buttons to control the player", 270)
        self:drawCenteredText("• Fire button shoots current weapon", 300)
        self:drawCenteredText("• Use button opens doors and activates switches", 330)
        self:drawCenteredText("• Map button toggles the automap", 360)
        self:drawCenteredText("• Weapon buttons select different weapons", 390)
        self:drawCenteredText("• This is the authentic original Doom experience!", 430)
        
    elseif self.game_state == "error" then
        self:drawCenteredText("Error: Unable to start Doom", self.canvas_height / 2 - 40)
        self:drawCenteredText("Check that a Doom port is installed", self.canvas_height / 2)
        self:drawCenteredText("and the WAD file is valid", self.canvas_height / 2 + 40)
        
    elseif self.game_state == "stopped" then
        self:drawCenteredText("Doom has ended", self.canvas_height / 2 - 20)
        self:drawCenteredText("Press Pause to return to game menu", self.canvas_height / 2 + 20)
    end
    
    BaseGame.renderGame(self)
end

function DoomGame:drawCenteredText(text, y)
    local font_size = 16
    local face = Font:getFace("cfont", font_size)
    
    local text_width = RenderText:sizeUtf8Text(0, face.size, face, text, true, false).x
    local text_x = (self.canvas_width - text_width) / 2
    
    self.canvas.bb:colorBlit(
        RenderText:renderUtf8Text(text, text_width, 0, face, true, false, Blitbuffer.COLOR_BLACK),
        text_x, y
    )
end

function DoomGame:onCloseWidget()
    self:cleanup()
    BaseGame.onCloseWidget(self)
end

function DoomGame:cleanup()
    -- Stop Doom process if running
    if self.process_running then
        local kill_cmd = "pkill -f 'doom.*" .. (self.wad_file and self.wad_file:match("([^/]+)$") or "doom") .. "'"
        os.execute(kill_cmd)
        self.process_running = false
        logger.info("Stopped Doom process")
    end
    
    -- Clean up temporary directory
    if self.temp_dir then
        os.execute("rm -rf " .. self.temp_dir)
    end
    
    logger.info("Doom cleanup completed")
end

function DoomGame:onTogglePause()
    if self.game_state == "stopped" or self.game_state == "error" then
        -- Return to main game menu
        UIManager:close(self)
        return true
    else
        -- Send pause key to Doom
        self:sendDoomKey(DOOM_KEYS.pause, false)
        return BaseGame.onTogglePause(self)
    end
end

function DoomGame:showDoomPortError()
    local error_msg = InfoMessage:new{
        text = _("No Doom port found on this system.\n\n") ..
               _("Please install one of these Doom ports:\n") ..
               _("• chocolate-doom (most authentic)\n") ..
               _("• prboom-plus (enhanced features)\n") ..
               _("• crispy-doom (quality of life improvements)\n") ..
               _("• gzdoom (modern features)\n\n") ..
               _("Install using your system package manager."),
        width = self.canvas_width and (self.canvas_width * 0.8) or 400,
    }
    UIManager:show(error_msg)
end

function DoomGame:showError(message)
    local error_msg = InfoMessage:new{
        text = message,
        width = self.canvas_width and (self.canvas_width * 0.8) or 400,
    }
    UIManager:show(error_msg)
end

return DoomGame