local parent_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
package.path = package.path .. ";" .. parent_dir .. "?.lua"
local BaseGame = require("basegame")
local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local Size = require("ui/size")
local _ = require("gettext")
local logger = require("logger")

local SnakeGame = BaseGame:new{
    game_title = _("Snake"),
    tick_interval = 0.2,
    board_width = 20,
    board_height = 15,
    block_size = nil, -- Will be calculated
}

function SnakeGame:initGame()
    -- Calculate block size based on available space
    local canvas_height = self.game_height - self.control_height
    self.block_size = math.min(
        math.floor(self.game_width / self.board_width),
        math.floor(canvas_height / self.board_height)
    )
    
    -- Initialize snake
    self.snake = {
        {x = math.floor(self.board_width / 2), y = math.floor(self.board_height / 2)}
    }
    self.direction = {x = 1, y = 0}
    self.next_direction = {x = 1, y = 0}
    
    -- Initialize food
    self:spawnFood()
    
    -- Game state
    self.score = 0
    self.game_over = false
end

function SnakeGame:addGameControls()
    local up_btn = Button:new{
        text = _("↑"),
        callback = function() self:changeDirection(0, -1) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local down_btn = Button:new{
        text = _("↓"),
        callback = function() self:changeDirection(0, 1) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local left_btn = Button:new{
        text = _("←"),
        callback = function() self:changeDirection(-1, 0) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local right_btn = Button:new{
        text = _("→"),
        callback = function() self:changeDirection(1, 0) end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    table.insert(self.controls, up_btn)
    table.insert(self.controls, down_btn)
    table.insert(self.controls, left_btn)
    table.insert(self.controls, right_btn)
end

function SnakeGame:changeDirection(dx, dy)
    -- Prevent reversing direction
    if self.direction.x + dx ~= 0 or self.direction.y + dy ~= 0 then
        self.next_direction = {x = dx, y = dy}
    end
end

function SnakeGame:spawnFood()
    repeat
        self.food = {
            x = math.random(1, self.board_width),
            y = math.random(1, self.board_height)
        }
    until not self:isSnakePosition(self.food.x, self.food.y)
end

function SnakeGame:isSnakePosition(x, y)
    for _, segment in ipairs(self.snake) do
        if segment.x == x and segment.y == y then
            return true
        end
    end
    return false
end

function SnakeGame:updateGame()
    if self.game_over then
        return
    end
    
    -- Update direction
    self.direction = self.next_direction
    
    -- Calculate new head position
    local head = self.snake[1]
    local new_head = {
        x = head.x + self.direction.x,
        y = head.y + self.direction.y
    }
    
    -- Check wall collision
    if new_head.x < 1 or new_head.x > self.board_width or
       new_head.y < 1 or new_head.y > self.board_height then
        self:gameOver()
        return
    end
    
    -- Check self collision
    if self:isSnakePosition(new_head.x, new_head.y) then
        self:gameOver()
        return
    end
    
    -- Add new head
    table.insert(self.snake, 1, new_head)
    
    -- Check food collision
    if new_head.x == self.food.x and new_head.y == self.food.y then
        self.score = self.score + 10
        self:spawnFood()
        
        -- Increase speed slightly
        self.tick_interval = math.max(0.05, self.tick_interval - 0.005)
    else
        -- Remove tail if no food eaten
        table.remove(self.snake)
    end
end

function SnakeGame:gameOver()
    self.game_over = true
    -- Could show game over dialog here
end

function SnakeGame:renderGame()
    -- Clear canvas
    self.canvas.bb:fill(Blitbuffer.COLOR_BLACK)
    
    -- Calculate board position
    local board_pixel_width = self.board_width * self.block_size
    local board_pixel_height = self.board_height * self.block_size
    local start_x = math.floor((self.game_width - board_pixel_width) / 2)
    local start_y = math.floor((self.canvas.height - board_pixel_height) / 2)
    
    -- Draw snake
    for i, segment in ipairs(self.snake) do
        local color = i == 1 and Blitbuffer.COLOR_GREEN or Blitbuffer.COLOR_DARK_GREEN
        self:drawBlock(start_x + (segment.x - 1) * self.block_size,
                      start_y + (segment.y - 1) * self.block_size,
                      color)
    end
    
    -- Draw food
    self:drawBlock(start_x + (self.food.x - 1) * self.block_size,
                  start_y + (self.food.y - 1) * self.block_size,
                  Blitbuffer.COLOR_RED)
    
    BaseGame.renderGame(self)
end

function SnakeGame:drawBlock(x, y, color)
    -- Draw filled rectangle for block
    self.canvas.bb:paintRect(x + 1, y + 1, self.block_size - 2, self.block_size - 2, color)
end

return SnakeGame