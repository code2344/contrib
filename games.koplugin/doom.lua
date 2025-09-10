local parent_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
package.path = package.path .. ";" .. parent_dir .. "?.lua"
local BaseGame = require("basegame")
local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local Size = require("ui/size")
local Font = require("ui/font")
local RenderText = require("ui/rendertext")
local _ = require("gettext")
local logger = require("logger")

local DoomGame = BaseGame:new{
    game_title = _("Doom"),
    tick_interval = 0.033, -- ~30 FPS
    wad_file = nil,
}

-- WAD file structure constants
local WAD_HEADER_SIZE = 12
local WAD_DIRECTORY_ENTRY_SIZE = 16

function DoomGame:init()
    if not self.wad_file then
        logger.err("No WAD file specified")
        return
    end
    
    if not self:loadWADFile() then
        logger.err("Failed to load WAD file")
        return
    end
    
    BaseGame.init(self)
end

function DoomGame:initGame()
    -- Initialize Doom game state
    self.player = {
        x = 0,
        y = 0,
        angle = 0,
        health = 100,
    }
    
    -- Simple 2D map for demonstration
    self.map = {
        width = 32,
        height = 32,
        walls = {},
    }
    
    -- Initialize simple map (normally would be loaded from WAD)
    for y = 1, self.map.height do
        self.map.walls[y] = {}
        for x = 1, self.map.width do
            -- Create simple border walls
            if x == 1 or x == self.map.width or y == 1 or y == self.map.height then
                self.map.walls[y][x] = 1
            else
                self.map.walls[y][x] = 0
            end
        end
    end
    
    -- Place player in center
    self.player.x = self.map.width / 2
    self.player.y = self.map.height / 2
    
    -- Raycasting settings
    self.fov = math.pi / 3 -- 60 degrees
    self.num_rays = 120
    self.max_depth = 20
    
    self.wad_loaded = true
end

function DoomGame:addGameControls()
    local forward_btn = Button:new{
        text = _("↑"),
        callback = function() self:movePlayer(1, 0) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local backward_btn = Button:new{
        text = _("↓"),
        callback = function() self:movePlayer(-1, 0) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local turn_left_btn = Button:new{
        text = _("◄"),
        callback = function() self:turnPlayer(-0.1) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local turn_right_btn = Button:new{
        text = _("►"),
        callback = function() self:turnPlayer(0.1) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local strafe_left_btn = Button:new{
        text = _("←"),
        callback = function() self:movePlayer(0, -1) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local strafe_right_btn = Button:new{
        text = _("→"),
        callback = function() self:movePlayer(0, 1) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    table.insert(self.controls, forward_btn)
    table.insert(self.controls, backward_btn)
    table.insert(self.controls, turn_left_btn)
    table.insert(self.controls, turn_right_btn)
    table.insert(self.controls, strafe_left_btn)
    table.insert(self.controls, strafe_right_btn)
end

function DoomGame:loadWADFile()
    -- Basic WAD file validation and parsing
    local file = io.open(self.wad_file, "rb")
    if not file then
        return false
    end
    
    -- Read WAD header
    local header = file:read(4)
    if header ~= "IWAD" and header ~= "PWAD" then
        file:close()
        return false
    end
    
    -- Read number of lumps and directory offset
    local num_lumps_data = file:read(4)
    local dir_offset_data = file:read(4)
    
    if not num_lumps_data or not dir_offset_data then
        file:close()
        return false
    end
    
    -- Convert bytes to numbers (little-endian)
    local num_lumps = string.byte(num_lumps_data, 1) + 
                      string.byte(num_lumps_data, 2) * 256 +
                      string.byte(num_lumps_data, 3) * 65536 +
                      string.byte(num_lumps_data, 4) * 16777216
    
    local dir_offset = string.byte(dir_offset_data, 1) + 
                       string.byte(dir_offset_data, 2) * 256 +
                       string.byte(dir_offset_data, 3) * 65536 +
                       string.byte(dir_offset_data, 4) * 16777216
    
    -- Store WAD info
    self.wad_info = {
        type = header,
        num_lumps = num_lumps,
        directory_offset = dir_offset,
        file_handle = file,
    }
    
    -- In a full implementation, we would parse the directory
    -- and load maps, textures, sounds, etc.
    
    logger.info("Loaded WAD file: " .. self.wad_file)
    logger.info("Type: " .. header .. ", Lumps: " .. num_lumps)
    
    return true
end

function DoomGame:movePlayer(forward, strafe)
    local move_speed = 0.1
    local new_x = self.player.x
    local new_y = self.player.y
    
    if forward ~= 0 then
        new_x = new_x + math.cos(self.player.angle) * forward * move_speed
        new_y = new_y + math.sin(self.player.angle) * forward * move_speed
    end
    
    if strafe ~= 0 then
        new_x = new_x + math.cos(self.player.angle + math.pi/2) * strafe * move_speed
        new_y = new_y + math.sin(self.player.angle + math.pi/2) * strafe * move_speed
    end
    
    -- Simple collision detection
    local map_x = math.floor(new_x)
    local map_y = math.floor(new_y)
    
    if map_x >= 1 and map_x <= self.map.width and
       map_y >= 1 and map_y <= self.map.height and
       self.map.walls[map_y][map_x] == 0 then
        self.player.x = new_x
        self.player.y = new_y
    end
end

function DoomGame:turnPlayer(angle_delta)
    self.player.angle = self.player.angle + angle_delta
    -- Normalize angle
    while self.player.angle < 0 do
        self.player.angle = self.player.angle + 2 * math.pi
    end
    while self.player.angle >= 2 * math.pi do
        self.player.angle = self.player.angle - 2 * math.pi
    end
end

function DoomGame:updateGame()
    if not self.wad_loaded then
        return
    end
    
    -- Update game logic (enemies, projectiles, etc.)
    -- In a full Doom implementation, this would be much more complex
end

function DoomGame:renderGame()
    if not self.wad_loaded then
        -- Show loading or error message
        self.canvas.bb:fill(Blitbuffer.COLOR_BLACK)
        self:drawText(self.canvas_width / 2, self.canvas_height / 2,
                     _("Loading WAD file..."), Blitbuffer.COLOR_WHITE)
        BaseGame.renderGame(self)
        return
    end
    
    -- Render 3D view using raycasting
    self:renderRaycast()
    
    BaseGame.renderGame(self)
end

function DoomGame:renderRaycast()
    self.canvas.bb:fill(Blitbuffer.COLOR_BLACK)
    
    local screen_width = self.canvas_width
    local screen_height = self.canvas_height
    
    -- Simple sky/floor colors
    local sky_color = Blitbuffer.COLOR_GRAY
    local floor_color = Blitbuffer.COLOR_BLACK
    
    -- Fill sky and floor
    self.canvas.bb:paintRect(0, 0, screen_width, screen_height / 2, sky_color)
    self.canvas.bb:paintRect(0, screen_height / 2, screen_width, screen_height / 2, floor_color)
    
    -- Cast rays and render walls
    for x = 0, screen_width - 1 do
        local ray_angle = self.player.angle - self.fov / 2 + (x / screen_width) * self.fov
        local distance = self:castRay(ray_angle)
        
        if distance < self.max_depth then
            -- Calculate wall height based on distance
            local wall_height = (screen_height / distance) * 0.5
            local wall_top = (screen_height - wall_height) / 2
            local wall_bottom = wall_top + wall_height
            
            -- Simple wall color based on distance
            local color_intensity = math.max(0.2, 1 - distance / self.max_depth)
            local wall_color = Blitbuffer.COLOR_WHITE
            
            -- Draw wall column
            self.canvas.bb:paintRect(x, wall_top, 1, wall_height, wall_color)
        end
    end
end

function DoomGame:castRay(angle)
    local step_size = 0.05
    local x = self.player.x
    local y = self.player.y
    local dx = math.cos(angle) * step_size
    local dy = math.sin(angle) * step_size
    
    for i = 1, self.max_depth / step_size do
        x = x + dx
        y = y + dy
        
        local map_x = math.floor(x)
        local map_y = math.floor(y)
        
        if map_x < 1 or map_x > self.map.width or
           map_y < 1 or map_y > self.map.height or
           self.map.walls[map_y][map_x] == 1 then
            return math.sqrt((x - self.player.x)^2 + (y - self.player.y)^2)
        end
    end
    
    return self.max_depth
end

function DoomGame:drawText(x, y, text, color)
    local font_size = 16
    local face = Font:getFace("cfont", font_size)
    
    local text_width = RenderText:sizeUtf8Text(0, face.size, face, text, true, false).x
    local text_x = x - text_width / 2
    local text_y = y
    
    self.canvas.bb:colorBlit(
        RenderText:renderUtf8Text(text, text_width, 0, face, true, false, color),
        text_x, text_y
    )
end

function DoomGame:onCloseWidget()
    if self.wad_info and self.wad_info.file_handle then
        self.wad_info.file_handle:close()
    end
    BaseGame.onCloseWidget(self)
end

return DoomGame