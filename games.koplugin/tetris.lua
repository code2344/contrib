local parent_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
package.path = package.path .. ";" .. parent_dir .. "?.lua"
local BaseGame = require("basegame")
local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local Size = require("ui/size")
local _ = require("gettext")
local logger = require("logger")

local TetrisGame = BaseGame:new{
    game_title = _("Tetris"),
    tick_interval = 0.5,
    board_width = 10,
    board_height = 20,
    block_size = nil, -- Will be calculated
}

-- Tetris pieces (tetrominoes)
local PIECES = {
    I = {
        {{1,1,1,1}},
        {{1},{1},{1},{1}},
    },
    O = {
        {{1,1},{1,1}},
    },
    T = {
        {{0,1,0},{1,1,1}},
        {{1,0},{1,1},{1,0}},
        {{1,1,1},{0,1,0}},
        {{0,1},{1,1},{0,1}},
    },
    S = {
        {{0,1,1},{1,1,0}},
        {{1,0},{1,1},{0,1}},
    },
    Z = {
        {{1,1,0},{0,1,1}},
        {{0,1},{1,1},{1,0}},
    },
    J = {
        {{1,0,0},{1,1,1}},
        {{1,1},{1,0},{1,0}},
        {{1,1,1},{0,0,1}},
        {{0,1},{0,1},{1,1}},
    },
    L = {
        {{0,0,1},{1,1,1}},
        {{1,0},{1,0},{1,1}},
        {{1,1,1},{1,0,0}},
        {{1,1},{0,1},{0,1}},
    },
}

local PIECE_COLORS = {
    I = Blitbuffer.COLOR_WHITE,
    O = Blitbuffer.COLOR_WHITE,
    T = Blitbuffer.COLOR_WHITE,
    S = Blitbuffer.COLOR_WHITE,
    Z = Blitbuffer.COLOR_WHITE,
    J = Blitbuffer.COLOR_WHITE,
    L = Blitbuffer.COLOR_WHITE,
}

function TetrisGame:initGame()
    -- Calculate block size based on available space
    local canvas_height = self.canvas_height
    self.block_size = math.min(
        math.floor(self.game_width / self.board_width),
        math.floor(canvas_height / self.board_height)
    )
    
    -- Initialize game board
    self.board = {}
    for y = 1, self.board_height do
        self.board[y] = {}
        for x = 1, self.board_width do
            self.board[y][x] = 0
        end
    end
    
    -- Game state
    self.score = 0
    self.level = 1
    self.lines_cleared = 0
    self.current_piece = nil
    self.current_x = 0
    self.current_y = 0
    self.current_rotation = 1
    
    self:spawnNewPiece()
end

function TetrisGame:addGameControls()
    local left_btn = Button:new{
        text = _("←"),
        callback = function() self:movePiece(-1, 0) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local right_btn = Button:new{
        text = _("→"),
        callback = function() self:movePiece(1, 0) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local rotate_btn = Button:new{
        text = _("↻"),
        callback = function() self:rotatePiece() end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local drop_btn = Button:new{
        text = _("↓"),
        callback = function() self:dropPiece() end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    table.insert(self.controls, left_btn)
    table.insert(self.controls, right_btn)
    table.insert(self.controls, rotate_btn)
    table.insert(self.controls, drop_btn)
end

function TetrisGame:spawnNewPiece()
    local piece_types = {"I", "O", "T", "S", "Z", "J", "L"}
    local piece_type = piece_types[math.random(#piece_types)]
    
    self.current_piece = {
        type = piece_type,
        shapes = PIECES[piece_type],
        color = PIECE_COLORS[piece_type],
    }
    self.current_rotation = 1
    self.current_x = math.floor(self.board_width / 2) - 1
    self.current_y = 1
    
    -- Check if game over
    if self:checkCollision(self.current_x, self.current_y, self.current_rotation) then
        self.game_running = false
        -- Show game over dialog
    end
end

function TetrisGame:movePiece(dx, dy)
    local new_x = self.current_x + dx
    local new_y = self.current_y + dy
    
    if not self:checkCollision(new_x, new_y, self.current_rotation) then
        self.current_x = new_x
        self.current_y = new_y
        return true
    end
    return false
end

function TetrisGame:rotatePiece()
    local new_rotation = (self.current_rotation % #self.current_piece.shapes) + 1
    
    if not self:checkCollision(self.current_x, self.current_y, new_rotation) then
        self.current_rotation = new_rotation
        return true
    end
    return false
end

function TetrisGame:dropPiece()
    while self:movePiece(0, 1) do
        -- Keep moving down until collision
    end
end

function TetrisGame:checkCollision(x, y, rotation)
    local shape = self.current_piece.shapes[rotation]
    
    for py = 1, #shape do
        for px = 1, #shape[py] do
            if shape[py][px] == 1 then
                local board_x = x + px
                local board_y = y + py - 1
                
                -- Check boundaries
                if board_x < 1 or board_x > self.board_width or
                   board_y > self.board_height then
                    return true
                end
                
                -- Check collision with existing blocks
                if board_y > 0 and self.board[board_y][board_x] ~= 0 then
                    return true
                end
            end
        end
    end
    
    return false
end

function TetrisGame:placePiece()
    local shape = self.current_piece.shapes[self.current_rotation]
    
    for py = 1, #shape do
        for px = 1, #shape[py] do
            if shape[py][px] == 1 then
                local board_x = self.current_x + px
                local board_y = self.current_y + py - 1
                
                if board_y > 0 and board_y <= self.board_height then
                    self.board[board_y][board_x] = self.current_piece.type
                end
            end
        end
    end
    
    self:clearLines()
    self:spawnNewPiece()
end

function TetrisGame:clearLines()
    local lines_to_clear = {}
    
    -- Find complete lines
    for y = 1, self.board_height do
        local line_complete = true
        for x = 1, self.board_width do
            if self.board[y][x] == 0 then
                line_complete = false
                break
            end
        end
        if line_complete then
            table.insert(lines_to_clear, y)
        end
    end
    
    -- Clear lines and move down
    for _, line in ipairs(lines_to_clear) do
        table.remove(self.board, line)
        table.insert(self.board, 1, {})
        for x = 1, self.board_width do
            self.board[1][x] = 0
        end
    end
    
    -- Update score
    local lines_count = #lines_to_clear
    if lines_count > 0 then
        self.lines_cleared = self.lines_cleared + lines_count
        self.score = self.score + lines_count * 100 * self.level
        self.level = math.floor(self.lines_cleared / 10) + 1
        
        -- Increase speed
        self.tick_interval = math.max(0.1, 0.5 - (self.level - 1) * 0.05)
    end
end

function TetrisGame:updateGame()
    if not self:movePiece(0, 1) then
        self:placePiece()
    end
end

function TetrisGame:renderGame()
    -- Clear canvas
    self.canvas.bb:fill(Blitbuffer.COLOR_BLACK)
    
    -- Calculate board position
    local board_pixel_width = self.board_width * self.block_size
    local board_pixel_height = self.board_height * self.block_size
    local start_x = math.floor((self.game_width - board_pixel_width) / 2)
    local start_y = math.floor((self.canvas_height - board_pixel_height) / 2)
    
    -- Draw board
    for y = 1, self.board_height do
        for x = 1, self.board_width do
            if self.board[y][x] ~= 0 then
                local color = PIECE_COLORS[self.board[y][x]] or Blitbuffer.COLOR_WHITE
                self:drawBlock(start_x + (x-1) * self.block_size,
                              start_y + (y-1) * self.block_size,
                              color)
            end
        end
    end
    
    -- Draw current piece
    if self.current_piece then
        local shape = self.current_piece.shapes[self.current_rotation]
        for py = 1, #shape do
            for px = 1, #shape[py] do
                if shape[py][px] == 1 then
                    local x = self.current_x + px - 1
                    local y = self.current_y + py - 2
                    if y >= 0 then
                        self:drawBlock(start_x + x * self.block_size,
                                      start_y + y * self.block_size,
                                      self.current_piece.color)
                    end
                end
            end
        end
    end
    
    BaseGame.renderGame(self)
end

function TetrisGame:drawBlock(x, y, color)
    -- Draw filled rectangle for block
    self.canvas.bb:paintRect(x, y, self.block_size, self.block_size, color)
    
    -- Draw border
    self.canvas.bb:paintRect(x, y, self.block_size, 1, Blitbuffer.COLOR_WHITE)
    self.canvas.bb:paintRect(x, y, 1, self.block_size, Blitbuffer.COLOR_WHITE)
    self.canvas.bb:paintRect(x + self.block_size - 1, y, 1, self.block_size, Blitbuffer.COLOR_WHITE)
    self.canvas.bb:paintRect(x, y + self.block_size - 1, self.block_size, 1, Blitbuffer.COLOR_WHITE)
end

return TetrisGame