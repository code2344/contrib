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

-- Doom game constants
local PLAYER_HEIGHT = 0.6
local PLAYER_SPEED = 0.05
local TURN_SPEED = 0.05
local SECTOR_HEIGHT_SCALE = 0.01
local WALL_HEIGHT_SCALE = 64

-- Thing types from Doom
local THING_TYPES = {
    [1] = "Player1Start",
    [2] = "Player2Start", 
    [3] = "Player3Start",
    [4] = "Player4Start",
    [11] = "DeathmatchStart",
    [3004] = "FormerHuman", -- Zombieman
    [9] = "FormerSergeant", -- Shotgun guy
    [65] = "FormerCaptain", -- Chaingun guy
    [3001] = "Imp",
    [3002] = "Demon",
    [58] = "Spectre",
    [3006] = "LostSoul",
    [3005] = "Cacodemon",
    [69] = "HellKnight",
    [3003] = "BaronOfHell",
    [68] = "Arachnotron",
    [71] = "PainElemental",
    [84] = "WolfensteinSS",
    [64] = "Archvile",
    [88] = "Boss",
    [89] = "BossShoot",
    [7] = "SpiderMastermind",
    [16] = "Cyberdemon",
    [2001] = "Shotgun",
    [2002] = "Chaingun",
    [2003] = "RocketLauncher",
    [2004] = "PlasmaRifle",
    [2005] = "Chainsaw",
    [2006] = "BFG9000",
    [2007] = "ClipBox",
    [2008] = "Shells",
    [2010] = "RocketAmmo",
    [2047] = "CellPack",
    [2048] = "ArmorBonus",
    [2049] = "HealthBonus",
    [2011] = "Stimpack",
    [2012] = "Medikit",
    [2013] = "Soulsphere",
    [2014] = "HealthPotion",
    [2015] = "ArmorHelmet",
    [2018] = "GreenArmor",
    [2019] = "BlueArmor"
}

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
        z = 0,
        angle = 0,
        health = 100,
        armor = 0,
        weapons = {[1] = true}, -- Start with fist
        current_weapon = 1,
        ammo = {
            bullets = 50,
            shells = 0,
            rockets = 0,
            cells = 0
        },
        keys = {
            blue = false,
            red = false,
            yellow = false
        }
    }
    
    -- Game state
    self.game_state = "playing" -- playing, paused, dead, victory
    self.current_level = "E1M1"
    self.score = 0
    
    -- Initialize level data
    self.level = {
        vertexes = {},
        linedefs = {},
        sidedefs = {},
        sectors = {},
        things = {},
        nodes = {},
        ssectors = {},
        segs = {},
        blockmap = {},
        reject = {}
    }
    
    -- Active entities
    self.entities = {}
    self.projectiles = {}
    
    -- Load the first level
    if not self:loadLevel(self.current_level) then
        logger.err("Failed to load level: " .. self.current_level)
        -- Fall back to simple demo level
        self:createDemoLevel()
    end
    
    -- Raycasting settings
    self.fov = math.pi / 3 -- 60 degrees
    self.max_depth = 2048
    self.screen_distance = 160
    
    self.wad_loaded = true
end

function DoomGame:createDemoLevel()
    -- Create a simple demo level if WAD loading fails
    self.level.vertexes = {
        {x = 0, y = 0},
        {x = 512, y = 0},
        {x = 512, y = 512},
        {x = 0, y = 512},
        {x = 256, y = 128},
        {x = 384, y = 128},
        {x = 384, y = 256},
        {x = 256, y = 256}
    }
    
    self.level.sectors = {
        {floor_height = 0, ceiling_height = 128, light_level = 160},
        {floor_height = 16, ceiling_height = 112, light_level = 200}
    }
    
    self.level.linedefs = {
        {v1 = 1, v2 = 2, front_sidedef = 1, back_sidedef = -1, flags = 1},
        {v1 = 2, v2 = 3, front_sidedef = 2, back_sidedef = -1, flags = 1},
        {v1 = 3, v2 = 4, front_sidedef = 3, back_sidedef = -1, flags = 1},
        {v1 = 4, v2 = 1, front_sidedef = 4, back_sidedef = -1, flags = 1},
        {v1 = 5, v2 = 6, front_sidedef = 5, back_sidedef = 6, flags = 0},
        {v1 = 6, v2 = 7, front_sidedef = 7, back_sidedef = 8, flags = 0},
        {v1 = 7, v2 = 8, front_sidedef = 9, back_sidedef = 10, flags = 0},
        {v1 = 8, v2 = 5, front_sidedef = 11, back_sidedef = 12, flags = 0}
    }
    
    self.level.sidedefs = {
        {sector = 1, x_offset = 0, y_offset = 0, upper_texture = "BROWNHUG", lower_texture = "-", middle_texture = "BROWNHUG"},
        {sector = 1, x_offset = 0, y_offset = 0, upper_texture = "BROWNHUG", lower_texture = "-", middle_texture = "BROWNHUG"},
        {sector = 1, x_offset = 0, y_offset = 0, upper_texture = "BROWNHUG", lower_texture = "-", middle_texture = "BROWNHUG"},
        {sector = 1, x_offset = 0, y_offset = 0, upper_texture = "BROWNHUG", lower_texture = "-", middle_texture = "BROWNHUG"},
        {sector = 1, x_offset = 0, y_offset = 0, upper_texture = "-", lower_texture = "-", middle_texture = "-"},
        {sector = 2, x_offset = 0, y_offset = 0, upper_texture = "-", lower_texture = "-", middle_texture = "-"},
        {sector = 2, x_offset = 0, y_offset = 0, upper_texture = "-", lower_texture = "-", middle_texture = "-"},
        {sector = 1, x_offset = 0, y_offset = 0, upper_texture = "-", lower_texture = "-", middle_texture = "-"},
        {sector = 2, x_offset = 0, y_offset = 0, upper_texture = "-", lower_texture = "-", middle_texture = "-"},
        {sector = 1, x_offset = 0, y_offset = 0, upper_texture = "-", lower_texture = "-", middle_texture = "-"},
        {sector = 1, x_offset = 0, y_offset = 0, upper_texture = "-", lower_texture = "-", middle_texture = "-"},
        {sector = 2, x_offset = 0, y_offset = 0, upper_texture = "-", lower_texture = "-", middle_texture = "-"}
    }
    
    self.level.things = {
        {x = 256, y = 256, angle = 0, type = 1, flags = 7}, -- Player start
        {x = 320, y = 192, angle = 0, type = 3004, flags = 7}, -- Zombieman
        {x = 320, y = 320, angle = 180, type = 2001, flags = 7}, -- Shotgun
        {x = 192, y = 192, angle = 0, type = 2012, flags = 7} -- Medikit
    }
    
    -- Set player start position
    self.player.x = 256
    self.player.y = 256
    self.player.z = 0
    
    -- Create entities from things
    self:spawnEntities()
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
        callback = function() self:turnPlayer(-TURN_SPEED) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local turn_right_btn = Button:new{
        text = _("►"),
        callback = function() self:turnPlayer(TURN_SPEED) end,
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
    
    local fire_btn = Button:new{
        text = _("Fire"),
        callback = function() self:fireWeapon() end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local use_btn = Button:new{
        text = _("Use"),
        callback = function() self:useAction() end,
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
    table.insert(self.controls, fire_btn)
    table.insert(self.controls, use_btn)
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
    local num_lumps = self:readInt32LE(num_lumps_data)
    local dir_offset = self:readInt32LE(dir_offset_data)
    
    -- Store WAD info
    self.wad_info = {
        type = header,
        num_lumps = num_lumps,
        directory_offset = dir_offset,
        file_handle = file,
        directory = {}
    }
    
    -- Read directory
    file:seek("set", dir_offset)
    for i = 1, num_lumps do
        local entry_data = file:read(WAD_DIRECTORY_ENTRY_SIZE)
        if not entry_data then
            break
        end
        
        local offset = self:readInt32LE(entry_data:sub(1, 4))
        local size = self:readInt32LE(entry_data:sub(5, 8))
        local name = entry_data:sub(9, 16):match("([^%z]*)")
        
        self.wad_info.directory[name] = {
            offset = offset,
            size = size,
            index = i
        }
    end
    
    logger.info("Loaded WAD file: " .. self.wad_file)
    logger.info("Type: " .. header .. ", Lumps: " .. num_lumps)
    
    return true
end

function DoomGame:readInt32LE(data)
    return string.byte(data, 1) + 
           string.byte(data, 2) * 256 +
           string.byte(data, 3) * 65536 +
           string.byte(data, 4) * 16777216
end

function DoomGame:readInt16LE(data)
    return string.byte(data, 1) + string.byte(data, 2) * 256
end

function DoomGame:loadLevel(level_name)
    if not self.wad_info or not self.wad_info.directory then
        return false
    end
    
    -- Look for level marker
    local level_lump = self.wad_info.directory[level_name]
    if not level_lump then
        logger.warn("Level " .. level_name .. " not found in WAD")
        return false
    end
    
    -- Load level data lumps
    local level_lumps = {
        "THINGS", "LINEDEFS", "SIDEDEFS", "VERTEXES", 
        "SEGS", "SSECTORS", "NODES", "SECTORS", 
        "REJECT", "BLOCKMAP"
    }
    
    for _, lump_name in ipairs(level_lumps) do
        local lump = self.wad_info.directory[lump_name]
        if lump and lump.index > level_lump.index and lump.index <= level_lump.index + 10 then
            self:loadLevelLump(lump_name, lump)
        end
    end
    
    -- Find player start
    self:findPlayerStart()
    
    -- Spawn entities
    self:spawnEntities()
    
    return true
end

function DoomGame:loadLevelLump(lump_name, lump_info)
    local file = self.wad_info.file_handle
    file:seek("set", lump_info.offset)
    local data = file:read(lump_info.size)
    
    if lump_name == "VERTEXES" then
        self:parseVertexes(data)
    elseif lump_name == "LINEDEFS" then
        self:parseLinedefs(data)
    elseif lump_name == "SIDEDEFS" then
        self:parseSidedefs(data)
    elseif lump_name == "SECTORS" then
        self:parseSectors(data)
    elseif lump_name == "THINGS" then
        self:parseThings(data)
    end
end

function DoomGame:parseVertexes(data)
    self.level.vertexes = {}
    local pos = 1
    while pos <= #data do
        local x = self:readInt16LE(data:sub(pos, pos + 1))
        local y = self:readInt16LE(data:sub(pos + 2, pos + 3))
        table.insert(self.level.vertexes, {x = x, y = y})
        pos = pos + 4
    end
end

function DoomGame:parseLinedefs(data)
    self.level.linedefs = {}
    local pos = 1
    while pos <= #data do
        local v1 = self:readInt16LE(data:sub(pos, pos + 1)) + 1  -- Lua 1-indexed
        local v2 = self:readInt16LE(data:sub(pos + 2, pos + 3)) + 1
        local flags = self:readInt16LE(data:sub(pos + 4, pos + 5))
        local special = self:readInt16LE(data:sub(pos + 6, pos + 7))
        local tag = self:readInt16LE(data:sub(pos + 8, pos + 9))
        local front_sidedef = self:readInt16LE(data:sub(pos + 10, pos + 11))
        local back_sidedef = self:readInt16LE(data:sub(pos + 12, pos + 13))
        
        if front_sidedef ~= 65535 then front_sidedef = front_sidedef + 1 end
        if back_sidedef ~= 65535 then back_sidedef = back_sidedef + 1 else back_sidedef = -1 end
        
        table.insert(self.level.linedefs, {
            v1 = v1, v2 = v2, flags = flags, special = special, tag = tag,
            front_sidedef = front_sidedef, back_sidedef = back_sidedef
        })
        pos = pos + 14
    end
end

function DoomGame:parseSidedefs(data)
    self.level.sidedefs = {}
    local pos = 1
    while pos <= #data do
        local x_offset = self:readInt16LE(data:sub(pos, pos + 1))
        local y_offset = self:readInt16LE(data:sub(pos + 2, pos + 3))
        local upper_texture = data:sub(pos + 4, pos + 11):match("([^%z]*)")
        local lower_texture = data:sub(pos + 12, pos + 19):match("([^%z]*)")
        local middle_texture = data:sub(pos + 20, pos + 27):match("([^%z]*)")
        local sector = self:readInt16LE(data:sub(pos + 28, pos + 29)) + 1
        
        table.insert(self.level.sidedefs, {
            x_offset = x_offset, y_offset = y_offset,
            upper_texture = upper_texture, lower_texture = lower_texture,
            middle_texture = middle_texture, sector = sector
        })
        pos = pos + 30
    end
end

function DoomGame:parseSectors(data)
    self.level.sectors = {}
    local pos = 1
    while pos <= #data do
        local floor_height = self:readInt16LE(data:sub(pos, pos + 1))
        local ceiling_height = self:readInt16LE(data:sub(pos + 2, pos + 3))
        local floor_texture = data:sub(pos + 4, pos + 11):match("([^%z]*)")
        local ceiling_texture = data:sub(pos + 12, pos + 19):match("([^%z]*)")
        local light_level = self:readInt16LE(data:sub(pos + 20, pos + 21))
        local special = self:readInt16LE(data:sub(pos + 22, pos + 23))
        local tag = self:readInt16LE(data:sub(pos + 24, pos + 25))
        
        table.insert(self.level.sectors, {
            floor_height = floor_height, ceiling_height = ceiling_height,
            floor_texture = floor_texture, ceiling_texture = ceiling_texture,
            light_level = light_level, special = special, tag = tag
        })
        pos = pos + 26
    end
end

function DoomGame:parseThings(data)
    self.level.things = {}
    local pos = 1
    while pos <= #data do
        local x = self:readInt16LE(data:sub(pos, pos + 1))
        local y = self:readInt16LE(data:sub(pos + 2, pos + 3))
        local angle = self:readInt16LE(data:sub(pos + 4, pos + 5))
        local type = self:readInt16LE(data:sub(pos + 6, pos + 7))
        local flags = self:readInt16LE(data:sub(pos + 8, pos + 9))
        
        table.insert(self.level.things, {
            x = x, y = y, angle = angle, type = type, flags = flags
        })
        pos = pos + 10
    end
end

function DoomGame:findPlayerStart()
    for _, thing in ipairs(self.level.things) do
        if thing.type == 1 then -- Player 1 start
            self.player.x = thing.x
            self.player.y = thing.y
            self.player.angle = math.rad(thing.angle)
            self.player.z = self:getFloorHeight(thing.x, thing.y) + PLAYER_HEIGHT
            return
        end
    end
    
    -- Fallback to center of first sector
    if #self.level.sectors > 0 then
        self.player.x = 0
        self.player.y = 0
        self.player.z = self.level.sectors[1].floor_height + PLAYER_HEIGHT
    end
end

function DoomGame:spawnEntities()
    self.entities = {}
    
    for _, thing in ipairs(self.level.things) do
        local thing_type = THING_TYPES[thing.type]
        if thing_type and thing_type ~= "Player1Start" then
            local entity = {
                x = thing.x,
                y = thing.y,
                z = self:getFloorHeight(thing.x, thing.y),
                angle = math.rad(thing.angle),
                type = thing.type,
                thing_type = thing_type,
                health = self:getEntityHealth(thing.type),
                active = true,
                sprite = self:getEntitySprite(thing.type)
            }
            
            table.insert(self.entities, entity)
        end
    end
end

function DoomGame:getEntityHealth(type)
    local health_map = {
        [3004] = 20, -- Zombieman
        [9] = 30,    -- Shotgun guy
        [3001] = 60, -- Imp
        [3002] = 150, -- Demon
        [3005] = 400, -- Cacodemon
        [3003] = 1000 -- Baron of Hell
    }
    return health_map[type] or 1
end

function DoomGame:getEntitySprite(type)
    -- Simplified sprite representation for e-ink display
    local sprite_map = {
        [3004] = "Z", -- Zombieman
        [9] = "S",    -- Shotgun guy
        [3001] = "I", -- Imp
        [3002] = "D", -- Demon
        [3005] = "C", -- Cacodemon
        [3003] = "B", -- Baron
        [2001] = "G", -- Shotgun pickup
        [2012] = "H"  -- Health pack
    }
    return sprite_map[type] or "?"
end

function DoomGame:movePlayer(forward, strafe)
    if self.game_state ~= "playing" then return end
    
    local new_x = self.player.x
    local new_y = self.player.y
    
    if forward ~= 0 then
        new_x = new_x + math.cos(self.player.angle) * forward * PLAYER_SPEED
        new_y = new_y + math.sin(self.player.angle) * forward * PLAYER_SPEED
    end
    
    if strafe ~= 0 then
        new_x = new_x + math.cos(self.player.angle + math.pi/2) * strafe * PLAYER_SPEED
        new_y = new_y + math.sin(self.player.angle + math.pi/2) * strafe * PLAYER_SPEED
    end
    
    -- Check collision with level geometry
    if self:canMove(new_x, new_y) then
        self.player.x = new_x
        self.player.y = new_y
        self.player.z = self:getFloorHeight(new_x, new_y) + PLAYER_HEIGHT
        
        -- Check for item pickups
        self:checkItemPickups()
    end
end

function DoomGame:canMove(x, y)
    -- Check against level linedefs for collision
    for _, linedef in ipairs(self.level.linedefs) do
        if self:lineBlocks(linedef, x, y) then
            return false
        end
    end
    return true
end

function DoomGame:lineBlocks(linedef, x, y)
    if linedef.back_sidedef == -1 then -- Solid wall
        local v1 = self.level.vertexes[linedef.v1]
        local v2 = self.level.vertexes[linedef.v2]
        
        -- Simple distance check to line
        local dist = self:pointToLineDistance(x, y, v1.x, v1.y, v2.x, v2.y)
        return dist < 16 -- Player radius
    end
    return false
end

function DoomGame:pointToLineDistance(px, py, x1, y1, x2, y2)
    local A = px - x1
    local B = py - y1
    local C = x2 - x1
    local D = y2 - y1
    
    local dot = A * C + B * D
    local len_sq = C * C + D * D
    
    if len_sq == 0 then return math.sqrt(A * A + B * B) end
    
    local param = dot / len_sq
    
    local xx, yy
    if param < 0 then
        xx, yy = x1, y1
    elseif param > 1 then
        xx, yy = x2, y2
    else
        xx = x1 + param * C
        yy = y1 + param * D
    end
    
    local dx = px - xx
    local dy = py - yy
    return math.sqrt(dx * dx + dy * dy)
end

function DoomGame:getFloorHeight(x, y)
    -- Find which sector the point is in
    local sector = self:findSector(x, y)
    if sector then
        return sector.floor_height
    end
    return 0
end

function DoomGame:findSector(x, y)
    -- Simple sector finding - in a real engine this would use BSP tree
    for i, sector in ipairs(self.level.sectors) do
        if self:pointInSector(x, y, i) then
            return sector
        end
    end
    return self.level.sectors[1] -- Fallback
end

function DoomGame:pointInSector(x, y, sector_index)
    -- Check if point is inside sector using ray casting
    local inside = false
    local sector_lines = {}
    
    -- Find all lines that bound this sector
    for _, linedef in ipairs(self.level.linedefs) do
        local front_sector = linedef.front_sidedef ~= -1 and self.level.sidedefs[linedef.front_sidedef].sector or nil
        local back_sector = linedef.back_sidedef ~= -1 and self.level.sidedefs[linedef.back_sidedef].sector or nil
        
        if front_sector == sector_index or back_sector == sector_index then
            table.insert(sector_lines, linedef)
        end
    end
    
    -- Simple point-in-polygon test
    for _, linedef in ipairs(sector_lines) do
        local v1 = self.level.vertexes[linedef.v1]
        local v2 = self.level.vertexes[linedef.v2]
        
        if ((v1.y > y) ~= (v2.y > y)) and 
           (x < (v2.x - v1.x) * (y - v1.y) / (v2.y - v1.y) + v1.x) then
            inside = not inside
        end
    end
    
    return inside
end

function DoomGame:checkItemPickups()
    for i, entity in ipairs(self.entities) do
        if entity.active and self:isPickupItem(entity.type) then
            local dist = math.sqrt((entity.x - self.player.x)^2 + (entity.y - self.player.y)^2)
            if dist < 32 then -- Pickup radius
                self:pickupItem(entity)
                entity.active = false
            end
        end
    end
end

function DoomGame:isPickupItem(type)
    return type == 2001 or type == 2012 or type == 2014 or type == 2019 -- Weapons, health, armor
end

function DoomGame:pickupItem(entity)
    if entity.type == 2001 then -- Shotgun
        self.player.weapons[2] = true
        self.player.ammo.shells = self.player.ammo.shells + 8
    elseif entity.type == 2012 then -- Medikit
        self.player.health = math.min(100, self.player.health + 25)
    elseif entity.type == 2014 then -- Health bonus
        self.player.health = math.min(200, self.player.health + 1)
    elseif entity.type == 2019 then -- Blue armor
        self.player.armor = math.max(self.player.armor, 100)
    end
end

function DoomGame:fireWeapon()
    if self.game_state ~= "playing" then return end
    
    local weapon = self.player.current_weapon
    if weapon == 1 then -- Fist
        self:meleeAttack()
    elseif weapon == 2 and self.player.ammo.shells > 0 then -- Shotgun
        self.player.ammo.shells = self.player.ammo.shells - 1
        self:fireHitscan(8, 5) -- 8 pellets, 5 damage each
    end
end

function DoomGame:meleeAttack()
    -- Find target in front of player
    local target = self:findTargetInDirection(self.player.angle, 64)
    if target then
        self:damageEntity(target, math.random(10, 40))
    end
end

function DoomGame:fireHitscan(pellets, damage)
    for i = 1, pellets do
        local spread = (math.random() - 0.5) * 0.2 -- Random spread
        local angle = self.player.angle + spread
        local target = self:findTargetInDirection(angle, 2048)
        if target then
            self:damageEntity(target, damage)
        end
    end
end

function DoomGame:findTargetInDirection(angle, range)
    local step = 8
    local x, y = self.player.x, self.player.y
    local dx, dy = math.cos(angle) * step, math.sin(angle) * step
    
    for dist = step, range, step do
        x, y = x + dx, y + dy
        
        -- Check for wall collision
        if not self:canMove(x, y) then
            break
        end
        
        -- Check for enemy
        for _, entity in ipairs(self.entities) do
            if entity.active and self:isEnemy(entity.type) then
                local ent_dist = math.sqrt((entity.x - x)^2 + (entity.y - y)^2)
                if ent_dist < 16 then
                    return entity
                end
            end
        end
    end
    
    return nil
end

function DoomGame:isEnemy(type)
    return type == 3004 or type == 9 or type == 3001 or type == 3002 or type == 3005 or type == 3003
end

function DoomGame:damageEntity(entity, damage)
    entity.health = entity.health - damage
    if entity.health <= 0 then
        entity.active = false
        self.score = self.score + self:getScoreValue(entity.type)
    end
end

function DoomGame:getScoreValue(type)
    local scores = {
        [3004] = 50,   -- Zombieman
        [9] = 65,      -- Shotgun guy
        [3001] = 200,  -- Imp
        [3002] = 400,  -- Demon
        [3005] = 500,  -- Cacodemon
        [3003] = 1000  -- Baron
    }
    return scores[type] or 0
end

function DoomGame:useAction()
    -- Check for doors, switches, etc. in front of player
    local use_range = 64
    local angle = self.player.angle
    local x = self.player.x + math.cos(angle) * use_range
    local y = self.player.y + math.sin(angle) * use_range
    
    -- Find nearest activatable linedef
    for _, linedef in ipairs(self.level.linedefs) do
        if linedef.special > 0 then -- Has a special action
            local v1 = self.level.vertexes[linedef.v1]
            local v2 = self.level.vertexes[linedef.v2]
            local dist = self:pointToLineDistance(x, y, v1.x, v1.y, v2.x, v2.y)
            
            if dist < 32 then
                self:activateLinedef(linedef)
                break
            end
        end
    end
end

function DoomGame:activateLinedef(linedef)
    -- Simple door/switch activation
    if linedef.special == 1 then -- Door open
        logger.info("Door activated")
    elseif linedef.special == 9 then -- Door open stay
        logger.info("Door opened permanently")
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
    if not self.wad_loaded or self.game_state ~= "playing" then
        return
    end
    
    -- Update entities (AI, movement, etc.)
    for _, entity in ipairs(self.entities) do
        if entity.active and self:isEnemy(entity.type) then
            self:updateEnemyAI(entity)
        end
    end
    
    -- Update projectiles
    for i = #self.projectiles, 1, -1 do
        local proj = self.projectiles[i]
        proj.x = proj.x + proj.dx
        proj.y = proj.y + proj.dy
        
        -- Check collision
        if not self:canMove(proj.x, proj.y) or 
           self:checkProjectileHit(proj) then
            table.remove(self.projectiles, i)
        end
    end
    
    -- Check win/lose conditions
    if self.player.health <= 0 then
        self.game_state = "dead"
    elseif self:allEnemiesDead() then
        self.game_state = "victory"
    end
end

function DoomGame:updateEnemyAI(entity)
    -- Simple AI: move towards player if in sight
    local dx = self.player.x - entity.x
    local dy = self.player.y - entity.y
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist < 512 and self:hasLineOfSight(entity.x, entity.y, self.player.x, self.player.y) then
        -- Move towards player
        local move_speed = 0.5
        entity.x = entity.x + (dx / dist) * move_speed
        entity.y = entity.y + (dy / dist) * move_speed
        
        -- Attack if close enough
        if dist < 64 and math.random() < 0.1 then
            self:enemyAttack(entity)
        end
    end
end

function DoomGame:hasLineOfSight(x1, y1, x2, y2)
    local steps = 20
    local dx = (x2 - x1) / steps
    local dy = (y2 - y1) / steps
    
    for i = 1, steps do
        local x = x1 + dx * i
        local y = y1 + dy * i
        if not self:canMove(x, y) then
            return false
        end
    end
    return true
end

function DoomGame:enemyAttack(entity)
    -- Simple melee attack
    local dist = math.sqrt((entity.x - self.player.x)^2 + (entity.y - self.player.y)^2)
    if dist < 64 then
        local damage = math.random(8, 24)
        self.player.health = self.player.health - damage
    end
end

function DoomGame:checkProjectileHit(proj)
    -- Check hit against entities
    for _, entity in ipairs(self.entities) do
        if entity.active then
            local dist = math.sqrt((entity.x - proj.x)^2 + (entity.y - proj.y)^2)
            if dist < 16 then
                self:damageEntity(entity, proj.damage)
                return true
            end
        end
    end
    return false
end

function DoomGame:allEnemiesDead()
    for _, entity in ipairs(self.entities) do
        if entity.active and self:isEnemy(entity.type) then
            return false
        end
    end
    return true
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
    
    -- Render 3D view using proper Doom-style rendering
    self:renderDoomView()
    
    -- Render HUD
    self:renderHUD()
    
    -- Render game state messages
    if self.game_state == "dead" then
        self:drawText(self.canvas_width / 2, self.canvas_height / 2,
                     _("YOU ARE DEAD"), Blitbuffer.COLOR_WHITE)
    elseif self.game_state == "victory" then
        self:drawText(self.canvas_width / 2, self.canvas_height / 2,
                     _("LEVEL COMPLETE"), Blitbuffer.COLOR_WHITE)
    end
    
    BaseGame.renderGame(self)
end

function DoomGame:renderDoomView()
    self.canvas.bb:fill(Blitbuffer.COLOR_BLACK)
    
    local screen_width = self.canvas_width
    local screen_height = self.canvas_height
    
    -- Render floor and ceiling
    local horizon = screen_height / 2
    self.canvas.bb:paintRect(0, 0, screen_width, horizon, Blitbuffer.COLOR_GRAY_4)  -- Sky
    self.canvas.bb:paintRect(0, horizon, screen_width, horizon, Blitbuffer.COLOR_GRAY)  -- Floor
    
    -- Cast rays for each screen column
    for x = 0, screen_width - 1 do
        local ray_angle = self.player.angle - self.fov / 2 + (x / screen_width) * self.fov
        self:castDoomRay(x, ray_angle)
    end
    
    -- Render sprites (entities)
    self:renderSprites()
end

function DoomGame:castDoomRay(screen_x, angle)
    local ray_result = self:performRaycast(angle)
    
    if ray_result.hit then
        -- Calculate wall height on screen
        local perp_distance = ray_result.distance * math.cos(angle - self.player.angle)
        local wall_height = self.screen_distance / perp_distance * WALL_HEIGHT_SCALE
        
        local wall_top = (self.canvas_height - wall_height) / 2
        local wall_bottom = wall_top + wall_height
        
        -- Determine wall color based on texture and lighting
        local color = self:getWallColor(ray_result.linedef, ray_result.side)
        
        -- Draw wall column
        self.canvas.bb:paintRect(screen_x, math.max(0, wall_top), 1, 
                                math.min(self.canvas_height, wall_bottom - wall_top), color)
    end
end

function DoomGame:performRaycast(angle)
    local step_size = 2
    local x, y = self.player.x, self.player.y
    local dx, dy = math.cos(angle) * step_size, math.sin(angle) * step_size
    
    for i = 1, self.max_depth / step_size do
        x, y = x + dx, y + dy
        
        -- Check intersection with level geometry
        for _, linedef in ipairs(self.level.linedefs) do
            if self:rayIntersectsLine(self.player.x, self.player.y, x, y, linedef) then
                local distance = math.sqrt((x - self.player.x)^2 + (y - self.player.y)^2)
                return {
                    hit = true,
                    distance = distance,
                    x = x,
                    y = y,
                    linedef = linedef,
                    side = self:determineSide(linedef, self.player.x, self.player.y)
                }
            end
        end
    end
    
    return {hit = false, distance = self.max_depth}
end

function DoomGame:rayIntersectsLine(x1, y1, x2, y2, linedef)
    local v1 = self.level.vertexes[linedef.v1]
    local v2 = self.level.vertexes[linedef.v2]
    
    -- Line intersection test
    local denom = (x1 - x2) * (v1.y - v2.y) - (y1 - y2) * (v1.x - v2.x)
    if math.abs(denom) < 0.001 then return false end
    
    local t = ((x1 - v1.x) * (v1.y - v2.y) - (y1 - v1.y) * (v1.x - v2.x)) / denom
    local u = -((x1 - x2) * (y1 - v1.y) - (y1 - y2) * (x1 - v1.x)) / denom
    
    return t >= 0 and t <= 1 and u >= 0 and u <= 1
end

function DoomGame:determineSide(linedef, x, y)
    local v1 = self.level.vertexes[linedef.v1]
    local v2 = self.level.vertexes[linedef.v2]
    
    local cross = (x - v1.x) * (v2.y - v1.y) - (y - v1.y) * (v2.x - v1.x)
    return cross >= 0 and "front" or "back"
end

function DoomGame:getWallColor(linedef, side)
    -- Simplified wall coloring based on texture and side
    if linedef.back_sidedef == -1 then
        return Blitbuffer.COLOR_WHITE  -- Solid wall
    else
        return Blitbuffer.COLOR_GRAY_E  -- Two-sided wall
    end
end

function DoomGame:renderSprites()
    -- Sort entities by distance for proper depth ordering
    local visible_entities = {}
    
    for _, entity in ipairs(self.entities) do
        if entity.active then
            local dx = entity.x - self.player.x
            local dy = entity.y - self.player.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- Check if entity is in front of player
            local angle_to_entity = math.atan2(dy, dx)
            local relative_angle = angle_to_entity - self.player.angle
            
            -- Normalize angle
            while relative_angle > math.pi do relative_angle = relative_angle - 2 * math.pi end
            while relative_angle < -math.pi do relative_angle = relative_angle + 2 * math.pi end
            
            if math.abs(relative_angle) < self.fov / 2 + 0.2 then -- Add some buffer
                table.insert(visible_entities, {
                    entity = entity,
                    distance = distance,
                    angle = relative_angle
                })
            end
        end
    end
    
    -- Sort by distance (farthest first)
    table.sort(visible_entities, function(a, b) return a.distance > b.distance end)
    
    -- Render sprites
    for _, visible in ipairs(visible_entities) do
        self:renderSprite(visible.entity, visible.distance, visible.angle)
    end
end

function DoomGame:renderSprite(entity, distance, relative_angle)
    -- Calculate screen position
    local screen_x = self.canvas_width / 2 + (relative_angle / (self.fov / 2)) * (self.canvas_width / 2)
    
    -- Calculate sprite size based on distance
    local sprite_size = math.max(8, 32 / distance * 100)
    
    -- Draw simple sprite representation
    local color = self:getSpriteColor(entity.type)
    self:drawText(screen_x, self.canvas_height / 2, entity.sprite, color)
end

function DoomGame:getSpriteColor(entity_type)
    if self:isEnemy(entity_type) then
        return Blitbuffer.COLOR_BLACK
    else
        return Blitbuffer.COLOR_GRAY
    end
end

function DoomGame:renderHUD()
    local hud_height = 60
    local hud_y = self.canvas_height - hud_height
    
    -- HUD background
    self.canvas.bb:paintRect(0, hud_y, self.canvas_width, hud_height, Blitbuffer.COLOR_GRAY_4)
    
    -- Health
    self:drawText(50, hud_y + 20, string.format("Health: %d", self.player.health), Blitbuffer.COLOR_BLACK)
    
    -- Armor
    self:drawText(50, hud_y + 35, string.format("Armor: %d", self.player.armor), Blitbuffer.COLOR_BLACK)
    
    -- Ammo
    local ammo_text = string.format("Shells: %d", self.player.ammo.shells)
    self:drawText(200, hud_y + 20, ammo_text, Blitbuffer.COLOR_BLACK)
    
    -- Score
    self:drawText(200, hud_y + 35, string.format("Score: %d", self.score), Blitbuffer.COLOR_BLACK)
    
    -- Current weapon
    local weapon_name = self.player.current_weapon == 1 and "Fist" or "Shotgun"
    self:drawText(350, hud_y + 20, weapon_name, Blitbuffer.COLOR_BLACK)
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