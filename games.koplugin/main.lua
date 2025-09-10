local Device = require("device")
local Dispatcher = require("dispatcher")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Menu = require("ui/widget/menu")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local TextWidget = require("ui/widget/textwidget")
local Button = require("ui/widget/button")
local Blitbuffer = require("ffi/blitbuffer")
local Screen = Device.screen
local Size = require("ui/size")
local Font = require("ui/font")
local _ = require("gettext")
local logger = require("logger")

-- Get plugin directory path
local PluginShare = require("pluginshare")
local parent_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")

-- Import game modules with full paths
package.path = package.path .. ";" .. parent_dir .. "?.lua"
local TetrisGame = require("tetris")
local SnakeGame = require("snake")
local PongGame = require("pong")
local MinesweeperGame = require("minesweeper")
local DoomGame = require("doom")

local Games = InputContainer:new{
    name = "games",
    is_doc_only = false,
    modal = true,
    width = Screen:getWidth(),
    height = Screen:getHeight(),
}

function Games:init()
    if Device:hasKeys() then
        self.key_events = {
            AnyKeyPressed = {
                { Input.group.Any },
                seqtext = "any key",
                doc = "close dialog"
            }
        }
    end
    
    if Device:isTouchDevice() then
        self.ges_events.TapClose = {
            GestureRange:new{
                ges = "tap",
                range = Geom:new{
                    x = 0, y = 0,
                    w = Screen:getWidth(),
                    h = Screen:getHeight()
                }
            }
        }
    end
    
    self:createGameMenu()
    self.ui.menu:registerToMainMenu(self)
    return self:onDispatcherRegisterAction()
end

function Games:createGameMenu()
    local game_list = {
        {
            text = _("Tetris"),
            callback = function()
                self:launchGame(TetrisGame)
            end
        },
        {
            text = _("Snake"),
            callback = function()
                self:launchGame(SnakeGame)
            end
        },
        {
            text = _("Pong"),
            callback = function()
                self:launchGame(PongGame)
            end
        },
        {
            text = _("Minesweeper"),
            callback = function()
                self:launchGame(MinesweeperGame)
            end
        },
        {
            text = _("Doom"),
            callback = function()
                self:launchDoom()
            end
        },
    }
    
    local title = TextWidget:new{
        text = _("Select a Game"),
        face = Font:getFace("tfont", 24),
        width = self.width,
        bold = true,
    }
    
    local menu_container = CenterContainer:new{
        dimen = Geom:new{
            w = self.width,
            h = self.height,
        }
    }
    
    local menu_frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Size.border.window,
        margin = Size.margin.default,
        padding = Size.padding.default,
    }
    
    local button_group = VerticalGroup:new{
        spacing = Size.spacing.default,
        title,
    }
    
    -- Create buttons for each game
    for _, game in ipairs(game_list) do
        local button = Button:new{
            text = game.text,
            callback = game.callback,
            bordersize = Size.border.button,
            margin = Size.margin.button,
            padding = Size.padding.button,
            width = Screen:scaleBySize(200),
        }
        table.insert(button_group, button)
    end
    
    menu_frame[1] = button_group
    menu_container[1] = menu_frame
    self[1] = menu_container
end

function Games:launchGame(GameClass)
    UIManager:close(self)
    local game_instance = GameClass:new{
        parent = self,
    }
    UIManager:show(game_instance)
end

function Games:launchDoom()
    -- Show file picker for WAD files
    local PathChooser = require("ui/widget/pathchooser")
    local path_chooser = PathChooser:new{
        select_file = true,
        file_filter = function(filename)
            return filename:lower():match("%.wad$")
        end,
        path = "/mnt/onboard",
        onConfirm = function(file_path)
            UIManager:close(self)
            local doom_instance = DoomGame:new{
                parent = self,
                wad_file = file_path,
            }
            UIManager:show(doom_instance)
        end,
    }
    UIManager:show(path_chooser)
end

function Games:addToMainMenu(menu_items)
    menu_items.games = {
        text = _("Games"),
        sorting_hint = "more_tools",
        callback = function()
            UIManager:show(self)
        end
    }
end

function Games:onCloseWidget()
    UIManager:setDirty(nil, function()
        return "ui", self[1].dimen
    end)
end

function Games:onShow()
    UIManager:setDirty(self, function()
        return "ui", self[1].dimen
    end)
end

function Games:onAnyKeyPressed()
    UIManager:close(self)
    return true
end

function Games:onTapClose()
    UIManager:close(self)
    return true
end

function Games:onDispatcherRegisterAction()
    Dispatcher:registerAction("games_show", {
        category = "none",
        event = "GamesShow",
        title = _("Show games"),
        device = true,
    })
end

function Games:onGamesShow()
    UIManager:show(self)
    return true
end

return Games