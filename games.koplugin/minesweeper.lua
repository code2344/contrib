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

local MinesweeperGame = BaseGame:new{
    game_title = _("Minesweeper"),
    tick_interval = 0.1, -- Not really needed for turn-based game
    board_width = 12,
    board_height = 10,
    mine_count = 15,
    cell_size = nil, -- Will be calculated
}

-- Cell states
local CELL_HIDDEN = 0
local CELL_REVEALED = 1
local CELL_FLAGGED = 2
local CELL_MINE = -1

function MinesweeperGame:initGame()
    -- Calculate cell size based on available space
    local canvas_height = self.game_height - self.control_height
    self.cell_size = math.min(
        math.floor(self.game_width / self.board_width),
        math.floor(canvas_height / self.board_height)
    )
    
    -- Initialize board
    self.board = {}
    self.revealed = {}
    self.flags = {}
    
    for y = 1, self.board_height do
        self.board[y] = {}
        self.revealed[y] = {}
        self.flags[y] = {}
        for x = 1, self.board_width do
            self.board[y][x] = 0 -- Number of adjacent mines
            self.revealed[y][x] = false
            self.flags[y][x] = false
        end
    end
    
    -- Place mines
    self:placeMines()
    
    -- Calculate numbers
    self:calculateNumbers()
    
    -- Game state
    self.game_over = false
    self.won = false
    self.flags_remaining = self.mine_count
    self.selected_x = 1
    self.selected_y = 1
    self.flag_mode = false
end

function MinesweeperGame:addGameControls()
    local up_btn = Button:new{
        text = _("↑"),
        callback = function() self:moveSelection(0, -1) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local down_btn = Button:new{
        text = _("↓"),
        callback = function() self:moveSelection(0, 1) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local left_btn = Button:new{
        text = _("←"),
        callback = function() self:moveSelection(-1, 0) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local right_btn = Button:new{
        text = _("→"),
        callback = function() self:moveSelection(1, 0) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local reveal_btn = Button:new{
        text = _("Reveal"),
        callback = function() self:revealCell(self.selected_x, self.selected_y) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local flag_btn = Button:new{
        text = _("Flag"),
        callback = function() self:toggleFlag(self.selected_x, self.selected_y) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    table.insert(self.controls, up_btn)
    table.insert(self.controls, down_btn)
    table.insert(self.controls, left_btn)
    table.insert(self.controls, right_btn)
    table.insert(self.controls, reveal_btn)
    table.insert(self.controls, flag_btn)
end

function MinesweeperGame:placeMines()
    local mines_placed = 0
    while mines_placed < self.mine_count do
        local x = math.random(1, self.board_width)
        local y = math.random(1, self.board_height)
        
        if self.board[y][x] ~= CELL_MINE then
            self.board[y][x] = CELL_MINE
            mines_placed = mines_placed + 1
        end
    end
end

function MinesweeperGame:calculateNumbers()
    for y = 1, self.board_height do
        for x = 1, self.board_width do
            if self.board[y][x] ~= CELL_MINE then
                local count = 0
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local nx, ny = x + dx, y + dy
                        if nx >= 1 and nx <= self.board_width and
                           ny >= 1 and ny <= self.board_height and
                           self.board[ny][nx] == CELL_MINE then
                            count = count + 1
                        end
                    end
                end
                self.board[y][x] = count
            end
        end
    end
end

function MinesweeperGame:moveSelection(dx, dy)
    self.selected_x = math.max(1, math.min(self.board_width, self.selected_x + dx))
    self.selected_y = math.max(1, math.min(self.board_height, self.selected_y + dy))
end

function MinesweeperGame:revealCell(x, y)
    if self.game_over or self.flags[y][x] or self.revealed[y][x] then
        return
    end
    
    self.revealed[y][x] = true
    
    if self.board[y][x] == CELL_MINE then
        self:gameOver(false)
        return
    end
    
    -- Auto-reveal adjacent cells if no mines nearby
    if self.board[y][x] == 0 then
        for dy = -1, 1 do
            for dx = -1, 1 do
                local nx, ny = x + dx, y + dy
                if nx >= 1 and nx <= self.board_width and
                   ny >= 1 and ny <= self.board_height and
                   not self.revealed[ny][nx] then
                    self:revealCell(nx, ny)
                end
            end
        end
    end
    
    self:checkWin()
end

function MinesweeperGame:toggleFlag(x, y)
    if self.game_over or self.revealed[y][x] then
        return
    end
    
    self.flags[y][x] = not self.flags[y][x]
    self.flags_remaining = self.flags_remaining + (self.flags[y][x] and -1 or 1)
end

function MinesweeperGame:checkWin()
    local revealed_count = 0
    for y = 1, self.board_height do
        for x = 1, self.board_width do
            if self.revealed[y][x] then
                revealed_count = revealed_count + 1
            end
        end
    end
    
    if revealed_count == self.board_width * self.board_height - self.mine_count then
        self:gameOver(true)
    end
end

function MinesweeperGame:gameOver(won)
    self.game_over = true
    self.won = won
    
    -- Reveal all mines
    if not won then
        for y = 1, self.board_height do
            for x = 1, self.board_width do
                if self.board[y][x] == CELL_MINE then
                    self.revealed[y][x] = true
                end
            end
        end
    end
end

function MinesweeperGame:updateGame()
    -- Turn-based game, no continuous updates needed
end

function MinesweeperGame:renderGame()
    -- Clear canvas
    self.canvas.bb:fill(Blitbuffer.COLOR_WHITE)
    
    -- Calculate board position
    local board_pixel_width = self.board_width * self.cell_size
    local board_pixel_height = self.board_height * self.cell_size
    local start_x = math.floor((self.game_width - board_pixel_width) / 2)
    local start_y = math.floor((self.canvas.height - board_pixel_height) / 2)
    
    -- Draw cells
    for y = 1, self.board_height do
        for x = 1, self.board_width do
            local cell_x = start_x + (x - 1) * self.cell_size
            local cell_y = start_y + (y - 1) * self.cell_size
            
            self:drawCell(cell_x, cell_y, x, y)
        end
    end
    
    BaseGame.renderGame(self)
end

function MinesweeperGame:drawCell(x, y, grid_x, grid_y)
    local size = self.cell_size
    local is_selected = (grid_x == self.selected_x and grid_y == self.selected_y)
    local is_revealed = self.revealed[grid_y][grid_x]
    local is_flagged = self.flags[grid_y][grid_x]
    local cell_value = self.board[grid_y][grid_x]
    
    -- Cell background
    local bg_color = Blitbuffer.COLOR_LIGHT_GRAY
    if is_revealed then
        bg_color = cell_value == CELL_MINE and Blitbuffer.COLOR_RED or Blitbuffer.COLOR_WHITE
    end
    
    self.canvas.bb:paintRect(x, y, size, size, bg_color)
    
    -- Cell border
    local border_color = is_selected and Blitbuffer.COLOR_BLUE or Blitbuffer.COLOR_BLACK
    self.canvas.bb:paintRect(x, y, size, 1, border_color)
    self.canvas.bb:paintRect(x, y, 1, size, border_color)
    self.canvas.bb:paintRect(x + size - 1, y, 1, size, border_color)
    self.canvas.bb:paintRect(x, y + size - 1, size, 1, border_color)
    
    -- Cell content
    if is_flagged then
        -- Draw flag (simple 'F')
        self:drawText(x, y, "F", Blitbuffer.COLOR_RED)
    elseif is_revealed then
        if cell_value == CELL_MINE then
            -- Draw mine (simple '*')
            self:drawText(x, y, "*", Blitbuffer.COLOR_BLACK)
        elseif cell_value > 0 then
            -- Draw number
            self:drawText(x, y, tostring(cell_value), Blitbuffer.COLOR_BLACK)
        end
    end
end

function MinesweeperGame:drawText(x, y, text, color)
    local size = self.cell_size
    local font_size = math.max(12, size - 6)
    local face = Font:getFace("cfont", font_size)
    
    -- Calculate text position (centered)
    local text_width = RenderText:sizeUtf8Text(0, face.size, face, text, true, false).x
    local text_x = x + (size - text_width) / 2
    local text_y = y + size / 2 + font_size / 3
    
    self.canvas.bb:colorBlit(
        RenderText:renderUtf8Text(text, text_width, 0, face, true, false, color),
        text_x, text_y
    )
end

return MinesweeperGame