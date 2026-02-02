local appSummaryWidgets = {}
local wx = require("wx")
local appWorkerThread = require("DistroCheck.appWorkerThread")
local green <const> = wx.wxColour("#13a256")
local red <const> = wx.wxColour("#e40521")
local default <const> = wx.wxNullColour
local colorTab = {[-1]=default, [0]=red, [1]=green}
local nye <const> = "Not yet evaluated"

local result1, result2, result3, result4, result5, result6, sizer

function appSummaryWidgets.reset()
   for _,v in ipairs({result1, result2, result3, result4, result5, result6}) do
      v:SetLabel(nye)
   end
   sizer:Layout()
end

local function addDottedStretchSpacer(parent, parentSizer)
   -- a dotted strech spacer of variable length. Places a line of dots
   -- to visually connect two rather distant labels
   local canvas = wx.wxPanel(parent, wx.wxID_ANY)
   parentSizer:Add(canvas, 1, wx.wxEXPAND + wx.wxALL,5)

   canvas:Connect(
      wx.wxEVT_PAINT, function()
	 -- get drawing context
	 local dc = wx.wxPaintDC(canvas)
	 -- get current width and heigth of canvas
	 local w, h = canvas:GetClientSizeWH()
	 -- use same font on dc as in canvas
	 dc:SetFont(canvas:GetFont())
	 -- slightly modify font color
	 dc:SetTextForeground(wx.wxColour(160, 160, 160))
	 -- Determine width and heigt of a single dot
	 local cW, cH = dc:GetTextExtent(".")
	 -- Calculate dot y-coordinate to middle (y counts top down)
	 local y = (h - cH) / 2
	 -- set two points starting space between adjoining dots
	 local x = 2
	 -- Fill dc with dots at given coodinates until canvas witdh is
	 -- reached (with another 2 pt ending space and with 1 dot
	 -- space between successive dots
	 while (x + cW < w - 2) do
            dc:DrawText(".", x, y)
            x = x + cW + 1
	 end
      end
   )
end

function appSummaryWidgets.create(parentSizer)

   -- Create elements
   local label1 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				  "Checksum Container Signature Verification",
				  wx.wxDefaultPosition,wx.wxDefaultSize)
   result1 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY, nye,
			     wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_RIGHT)
   local label2 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				  "Number of Files matching SHA256 Digest",
				  wx.wxDefaultPosition,wx.wxDefaultSize)
   result2 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY, nye,
			     wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_RIGHT)
   local label3 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				  "Number of Files not matching SHA256 Digest",
				  wx.wxDefaultPosition,wx.wxDefaultSize)
   result3 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY, nye,
			     wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_RIGHT)
   local label4 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				  "Files on Disk but not in Checksum Container",
				  wx.wxDefaultPosition,wx.wxDefaultSize)
   result4 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY, nye,
			     wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_RIGHT)
   local label5 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				  "Files in Checksum Container but not on Disk",
				  wx.wxDefaultPosition,wx.wxDefaultSize)
   result5 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY, nye,
			     wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_RIGHT)
   local label6 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				  "Files locked by other Processes",
				  wx.wxDefaultPosition,wx.wxDefaultSize)
   result6 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY, nye,
			     wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_RIGHT)
   -- Create sizer and add elements
   sizer = wx.wxBoxSizer(wx.wxVERTICAL)

   local sizer1 = wx.wxBoxSizer(wx.wxHORIZONTAL)
   sizer1:Add(label1,0,wx.wxALL,5)
   addDottedStretchSpacer(parentSizer:GetStaticBox(), sizer1)
   sizer1:Add(result1,0,wx.wxALL,5)
   sizer:Add(sizer1,1,wx.wxEXPAND)

   local sizer2 = wx.wxBoxSizer(wx.wxHORIZONTAL)
   sizer2:Add(label2,0,wx.wxALL,5)
   addDottedStretchSpacer(parentSizer:GetStaticBox(), sizer2)
   sizer2:Add(result2,0,wx.wxALL,5)
   sizer:Add(sizer2,1,wx.wxEXPAND)

   local sizer3 = wx.wxBoxSizer(wx.wxHORIZONTAL)
   sizer3:Add(label3,0,wx.wxALL,5)
   addDottedStretchSpacer(parentSizer:GetStaticBox(), sizer3)
   sizer3:Add(result3,0,wx.wxALL,5)
   sizer:Add(sizer3,1,wx.wxEXPAND)

   local sizer4 = wx.wxBoxSizer(wx.wxHORIZONTAL)
   sizer4:Add(label4,0,wx.wxALL,5)
   addDottedStretchSpacer(parentSizer:GetStaticBox(), sizer4)
   sizer4:Add(result4,0,wx.wxALL,5)
   sizer:Add(sizer4,1,wx.wxEXPAND)

   local sizer5 = wx.wxBoxSizer(wx.wxHORIZONTAL)
   sizer5:Add(label5,0,wx.wxALL,5)
   addDottedStretchSpacer(parentSizer:GetStaticBox(), sizer5)
   sizer5:Add(result5,0,wx.wxALL,5)
   sizer:Add(sizer5,1,wx.wxEXPAND)

   local sizer6 = wx.wxBoxSizer(wx.wxHORIZONTAL)
   sizer6:Add(label6,0,wx.wxALL,6)
   addDottedStretchSpacer(parentSizer:GetStaticBox(), sizer6)
   sizer6:Add(result6,0,wx.wxALL,6)
   sizer:Add(sizer6,1,wx.wxEXPAND)

   -- Add to higher level element
   parentSizer:Add(sizer,1,wx.wxEXPAND)

   -- Register event receivers
   appWorkerThread.registerReceiver("passfailDll", result1)
   appWorkerThread.registerReceiver("passCnt", result2)
   appWorkerThread.registerReceiver("failCnt", result3)
   appWorkerThread.registerReceiver("onlyOnDiskCnt", result4)
   appWorkerThread.registerReceiver("onlyInHashCnt", result5)
   appWorkerThread.registerReceiver("lockedByOtherProcsCnt", result6)

   -- Events
   result1:Connect(
      wx.wxEVT_THREAD,
      function(event)
	 result1:SetLabel(event:GetString())
	 result1:SetForegroundColour(colorTab[event:GetInt()])
	 result1:Refresh()
	 sizer:Layout()
      end
   )
   local labelTab = {passCnt=result2, failCnt=result3, onlyOnDiskCnt=result4,
		     onlyInHashCnt=result5, lockedByOtherProcsCnt=result6}
   local function receiveNumber(event)
      local target = labelTab[event:GetString()]
      target:SetLabel(tostring(event:GetExtraLong()))
      target:SetForegroundColour(colorTab[event:GetInt()])
      target:Refresh()
      sizer:Layout()
   end
   result2:Connect(wx.wxEVT_THREAD,receiveNumber)
   result3:Connect(wx.wxEVT_THREAD,receiveNumber)
   result4:Connect(wx.wxEVT_THREAD,receiveNumber)
   result5:Connect(wx.wxEVT_THREAD,receiveNumber)
   result6:Connect(wx.wxEVT_THREAD,receiveNumber)

end

return appSummaryWidgets
