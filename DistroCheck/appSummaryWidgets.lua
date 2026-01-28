local appSummaryWidgets = {}
local wx = require("wx")
local appWorkerThread = require("DistroCheck.appWorkerThread")
local green <const> = wx.wxColour("#13a256")
local red <const> = wx.wxColour("#e40521")
local boldFont <const> = wx.wxFont(wx.wxFontInfo():Bold())
local colorTab = {[0]=red, [1]=green}


function appSummaryWidgets.create(parentSizer)

   -- Create elements
   local label1 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				  "Checksum DLL Signature Verification",
				  wx.wxDefaultPosition,wx.wxDefaultSize)
   local result1 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				   "Not yet evaluated",
				   wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_RIGHT)
   local label2 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				  "Number of Files matching SHA256 Digest",
				  wx.wxDefaultPosition,wx.wxDefaultSize)
   local result2 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				   "Not yet evaluated",
				   wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_RIGHT)
   local label3 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				  "Number of Files not matching SHA256 Digest",
				  wx.wxDefaultPosition,wx.wxDefaultSize)
   local result3 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				   "Not yet evaluated",
				   wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_RIGHT)
   local label4 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				  "Files on Disk but not in Checksum Container (except Checksum File)",
				  wx.wxDefaultPosition,wx.wxDefaultSize)
   local result4 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				   "Not yet evaluated",
				   wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_RIGHT)
   local label5 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				  "Files in Checksum Container but not on Disk",
				  wx.wxDefaultPosition,wx.wxDefaultSize)
   local result5 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				   "Not yet evaluated",
				   wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_RIGHT)
   local label6 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				  "Files locked by other Processes",
				  wx.wxDefaultPosition,wx.wxDefaultSize)
   local result6 = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				   "Not yet evaluated",
				   wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_RIGHT)
   -- Create sizer and add elements
   local sizer = wx.wxFlexGridSizer(6,2)
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

   -- Register widget handles
   appWorkerThread.registerHandle("passfailDll", result1)

   -- Events
   result1:Connect(
      wx.wxEVT_THREAD,
      function(event)
	 result1:SetLabel(event:GetString())
	 result1:SetForegroundColour(colorTab[event:GetInt()])
	 result1:SetFont(boldFont)
	 sizer:Layout()
      end
   )

end

return appSummaryWidgets
