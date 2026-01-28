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

function appSummaryWidgets.create(parentSizer)

   -- Create elements
   local label1 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				  "Checksum DLL Signature Verification",
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
				  "Files on Disk but not in Checksum Container (except Checksum File)",
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
   sizer = wx.wxFlexGridSizer(6,2)
   sizer:AddGrowableCol(1, 1)
   sizer:Add(label1,1,wx.wxEXPAND + wx.wxALL,5)
   sizer:Add(result1,1,wx.wxALIGN_RIGHT + wx.wxALL,5)
   sizer:Add(label2,1,wx.wxEXPAND + wx.wxALL,5)
   sizer:Add(result2,1,wx.wxALIGN_RIGHT + wx.wxALL,5)
   sizer:Add(label3,1,wx.wxEXPAND + wx.wxALL,5)
   sizer:Add(result3,1,wx.wxALIGN_RIGHT + wx.wxALL,5)
   sizer:Add(label4,1,wx.wxEXPAND + wx.wxALL,5)
   sizer:Add(result4,1,wx.wxALIGN_RIGHT + wx.wxALL,5)
   sizer:Add(label5,1,wx.wxEXPAND + wx.wxALL,5)
   sizer:Add(result5,1,wx.wxALIGN_RIGHT + wx.wxALL,5)
   sizer:Add(label6,1,wx.wxEXPAND + wx.wxALL,5)
   sizer:Add(result6,1,wx.wxALIGN_RIGHT + wx.wxALL,5)
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
	 sizer:Layout()
      end
   )
   local labelTab = {passCnt=result2, failCnt=result3, onlyOnDiskCnt=result4,
		     onlyInHashCnt=result5, lockedByOtherProcsCnt=result6}
   local function receiveNumber(event)
      local target = labelTab[event:GetString()]
      target:SetLabel(tostring(event:GetExtraLong()))
      target:SetForegroundColour(colorTab[event:GetInt()])
      sizer:Layout()
   end
   result2:Connect(wx.wxEVT_THREAD,receiveNumber)
   result3:Connect(wx.wxEVT_THREAD,receiveNumber)
   result4:Connect(wx.wxEVT_THREAD,receiveNumber)
   result5:Connect(wx.wxEVT_THREAD,receiveNumber)
   result6:Connect(wx.wxEVT_THREAD,receiveNumber)

end

return appSummaryWidgets
