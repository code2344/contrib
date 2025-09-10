local parent_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
package.path = package.path .. ";" .. parent_dir .. "?.lua"
local BaseGame = require("basegame")
local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local Size = require("ui/size")
local _ = require("gettext")
local logger = require("logger")

local PongGame = BaseGame:new{
    game_title = _("Pong"),
    tick_interval = 0.03, -- 30 FPS
}

function PongGame:initGame()
    -- Game dimensions
    self.game_width = self.canvas.width
    self.game_height = self.canvas.height
    
    -- Paddle settings
    self.paddle_width = 10
    self.paddle_height = 80
    self.paddle_speed = 5
    
    -- Ball settings
    self.ball_size = 8
    self.ball_speed = 3
    
    -- Initialize game objects
    self.left_paddle = {
        x = 20,
        y = self.game_height / 2 - self.paddle_height / 2,
        dy = 0
    }
    
    self.right_paddle = {
        x = self.game_width - 20 - self.paddle_width,
        y = self.game_height / 2 - self.paddle_height / 2,
        dy = 0
    }
    
    self.ball = {
        x = self.game_width / 2,
        y = self.game_height / 2,
        dx = self.ball_speed * (math.random() < 0.5 and -1 or 1),
        dy = self.ball_speed * (math.random() - 0.5) * 2
    }
    
    -- Score
    self.left_score = 0
    self.right_score = 0
    
    -- AI difficulty
    self.ai_speed = 2
end

function PongGame:addGameControls()
    local up_btn = Button:new{
        text = _("↑"),
        callback = function() self.left_paddle.dy = -self.paddle_speed end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local down_btn = Button:new{
        text = _("↓"),
        callback = function() self.left_paddle.dy = self.paddle_speed end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    local stop_btn = Button:new{
        text = _("Stop"),
        callback = function() self.left_paddle.dy = 0 end,
        bordersize = Size.border.button,
        margin = Size.margin.button,
        padding = Size.padding.button,
    }
    
    table.insert(self.controls, up_btn)
    table.insert(self.controls, down_btn)
    table.insert(self.controls, stop_btn)
end

function PongGame:updateGame()
    -- Update left paddle (player)
    self.left_paddle.y = self.left_paddle.y + self.left_paddle.dy
    self.left_paddle.y = math.max(0, math.min(self.game_height - self.paddle_height, self.left_paddle.y))
    
    -- Update right paddle (AI)
    local paddle_center = self.right_paddle.y + self.paddle_height / 2
    local ball_center = self.ball.y + self.ball_size / 2
    
    if ball_center < paddle_center - 5 then
        self.right_paddle.y = self.right_paddle.y - self.ai_speed
    elseif ball_center > paddle_center + 5 then
        self.right_paddle.y = self.right_paddle.y + self.ai_speed
    end
    
    self.right_paddle.y = math.max(0, math.min(self.game_height - self.paddle_height, self.right_paddle.y))
    
    -- Update ball
    self.ball.x = self.ball.x + self.ball.dx
    self.ball.y = self.ball.y + self.ball.dy
    
    -- Ball collision with top/bottom walls
    if self.ball.y <= 0 or self.ball.y >= self.game_height - self.ball_size then
        self.ball.dy = -self.ball.dy
        self.ball.y = math.max(0, math.min(self.game_height - self.ball_size, self.ball.y))
    end
    
    -- Ball collision with paddles
    if self:ballPaddleCollision(self.left_paddle) or self:ballPaddleCollision(self.right_paddle) then
        self.ball.dx = -self.ball.dx
        
        -- Add some randomness to ball direction
        self.ball.dy = self.ball.dy + (math.random() - 0.5) * 2
        
        -- Limit ball speed
        self.ball.dy = math.max(-6, math.min(6, self.ball.dy))
    end
    
    -- Ball out of bounds (scoring)
    if self.ball.x < 0 then
        self.right_score = self.right_score + 1
        self:resetBall()
    elseif self.ball.x > self.game_width then
        self.left_score = self.left_score + 1
        self:resetBall()
    end
end

function PongGame:ballPaddleCollision(paddle)
    return self.ball.x < paddle.x + self.paddle_width and
           self.ball.x + self.ball_size > paddle.x and
           self.ball.y < paddle.y + self.paddle_height and
           self.ball.y + self.ball_size > paddle.y
end

function PongGame:resetBall()
    self.ball.x = self.game_width / 2
    self.ball.y = self.game_height / 2
    self.ball.dx = self.ball_speed * (math.random() < 0.5 and -1 or 1)
    self.ball.dy = self.ball_speed * (math.random() - 0.5) * 2
end

function PongGame:renderGame()
    -- Clear canvas
    self.canvas.bb:fill(Blitbuffer.COLOR_BLACK)
    
    -- Draw center line
    for y = 0, self.game_height, 20 do
        self.canvas.bb:paintRect(self.game_width / 2 - 1, y, 2, 10, Blitbuffer.COLOR_WHITE)
    end
    
    -- Draw paddles
    self.canvas.bb:paintRect(self.left_paddle.x, self.left_paddle.y,
                            self.paddle_width, self.paddle_height, Blitbuffer.COLOR_WHITE)
    self.canvas.bb:paintRect(self.right_paddle.x, self.right_paddle.y,
                            self.paddle_width, self.paddle_height, Blitbuffer.COLOR_WHITE)
    
    -- Draw ball
    self.canvas.bb:paintRect(self.ball.x, self.ball.y,
                            self.ball_size, self.ball_size, Blitbuffer.COLOR_WHITE)
    
    BaseGame.renderGame(self)
end

return PongGame