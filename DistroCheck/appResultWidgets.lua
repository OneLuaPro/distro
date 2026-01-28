local appResultWidgets = {}
local wx = require("wx")
local appWorkerThread = require("DistroCheck.appWorkerThread")

local nya <const> = "Result not yet available"
local boldFont <const> = wx.wxFont(wx.wxFontInfo():Bold())
local green <const> = wx.wxColour("#13a256")
local red <const> = wx.wxColour("#e40521")
local default <const> = wx.wxNullColour
local colorTab = {[-1]=default, [0]=red, [1]=green}

local label, sizer

function appResultWidgets.reset()
   label:SetLabel(nya,wx.wxALIGN_CENTRE)
   label:SetForegroundColour(default)
   sizer:Layout()
end

function appResultWidgets.create(parentSizer)

   -- Create elements
   label = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY, nya,
			   wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_CENTRE)
   label:SetFont(boldFont)
   -- Create sizer and add elements
   sizer = wx.wxBoxSizer(wx.wxVERTICAL)
   sizer:Add(label,1,wx.wxEXPAND + wx.wxALL,5)

   -- Add to higher level element
   parentSizer:Add(sizer,1,wx.wxEXPAND)

   -- Register event receiver
   appWorkerThread.registerReceiver("finalResult", label)

   -- Connect events
   label:Connect(
      wx.wxEVT_THREAD,
      function(event)
	 -- get enabled / disabled by worker thread
	 label:SetLabel(event:GetString())
	 label:SetForegroundColour(colorTab[event:GetInt()])
	 sizer:Layout()
      end
   )

end

return appResultWidgets
