local appLogWidgets = {}
local wx = require("wx")
local appWorkerThread = require("DistroCheck.appWorkerThread")

local ttFont <const> = wx.wxFont(wx.wxFontInfo():Family(wx.wxFONTFAMILY_TELETYPE))
local logOutput, logGauge

function appLogWidgets.append(text)
   logOutput:AppendText(text)
end

function appLogWidgets.clear()
   logOutput:Clear()
end

function appLogWidgets.create(parentSizer)

   -- Create elements
   logOutput = wx.wxTextCtrl(parentSizer:GetStaticBox(), wx.wxID_ANY, "",
			     wx.wxDefaultPosition, wx.wxDefaultSize,
			     wx.wxTE_READONLY + wx.wxTE_MULTILINE +
			     wx.wxHSCROLL)
   logOutput:SetFont(ttFont)
   logGauge = wx.wxGauge(parentSizer:GetStaticBox(), wx.wxID_ANY, 100,
			 wx.wxDefaultPosition, wx.wxDefaultSize,
			 wx.wxGA_HORIZONTAL + wx.wxGA_SMOOTH)

   -- Create sizer and add elements
   local sizer = wx.wxBoxSizer(wx.wxVERTICAL)
   sizer:Add(logOutput,1,wx.wxEXPAND + wx.wxALL,5)
   sizer:Add(logGauge,0,wx.wxEXPAND + wx.wxALL,5)

   -- Add to higher level element
   parentSizer:Add(sizer,1,wx.wxEXPAND)

   -- Register event receivers
   appWorkerThread.registerReceiver("logOutput", logOutput)
   appWorkerThread.registerReceiver("logGauge", logGauge)

   -- Connect events
   logOutput:Connect(
      wx.wxEVT_THREAD,
      function(event)
	 -- simply append all strings from received event
	 logOutput:AppendText(event:GetString())
      end
   )
   logGauge:Connect(
      wx.wxEVT_THREAD,
      function(event)
	 local range = event:GetExtraLong()
	 local value = event:GetInt()
	 if range == 0 and value == 0 then
	    -- gauge in indeterminate (pulsing) mode
	    logGauge:Pulse()
	 else
	    -- gauge in progress mode
	    logGauge:SetRange(range)
	    logGauge:SetValue(value)
	 end
      end
   )

end

return appLogWidgets
