local appConfig = {}
-- All stuff in relation to the gui config object
local wx = require("wx")

local config, frame
local localConfigFile <const> = "DistroCheck.ini"
local WINDOW_X <const> = "Window/X"
local WINDOW_Y <const> = "Window/Y"
local WINDOW_WIDTH <const> = "Window/Width"
local WINDOW_HEIGHT <const> = "Window/Height"


function appConfig.create(parent)
   -- create config object and pass it to other code ini-file will be created locally in
   -- C:\Users\<username>\AppData\Roaming
   config = wx.wxFileConfig("DistroCheck", "The OneLuaPro Developers", localConfigFile)
   config:SetExpandEnvVars(false)
   -- save reference to main frame
   frame = parent
   --
   return config
end

function appConfig.setFrame()
   -- read main window config from file (if data avaibale)
   if config:HasEntry("Window/X") and config:HasEntry("Window/Y") and
      config:HasEntry("Window/Width") and config:HasEntry("Window/Height") then
      -- Read values with defaults
      local _, x = config:Read(WINDOW_X)
      local _, y = config:Read(WINDOW_Y)
      local _, w = config:Read(WINDOW_WIDTH)
      local _, h = config:Read(WINDOW_HEIGHT)
      -- io.write(string.format("RD-CONFIG: x=%s\ty=%s\tw=%s\th=%s\n",x,y,w,h)):flush()
      -- Apply to frame
      frame:SetSize(wx.wxSize(tonumber(w), tonumber(h)))
      frame:Move(wx.wxPoint(tonumber(x), tonumber(y)))
   else
      -- use suggested default size
      frame:SetSize(wx.wxSize(720, 550))
   end
end

function appConfig.saveAll()
   -- save main window position
   -- Get window position and size
   local x, y = frame:GetPosition():GetX(), frame:GetPosition():GetY()
   local w, h = frame:GetSize():GetWidth(), frame:GetSize():GetHeight()
   config:Write(WINDOW_X, x)
   config:Write(WINDOW_Y, y)
   config:Write(WINDOW_WIDTH, w)
   config:Write(WINDOW_HEIGHT, h)
   --
   -- appConfig.saveToFile(config)
   -- flush config
   config:Flush()
end

return appConfig
