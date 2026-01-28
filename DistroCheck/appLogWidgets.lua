local appLogWidgets = {}
local wx = require("wx")
local appWorkerThread = require("DistroCheck.appWorkerThread")

local ttFont <const> = wx.wxFont(wx.wxFontInfo():Family(wx.wxFONTFAMILY_TELETYPE))
local logOutput

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

   -- Create sizer and add elements
   local sizer = wx.wxBoxSizer(wx.wxVERTICAL)
   sizer:Add(logOutput,1,wx.wxEXPAND + wx.wxALL,5)

   -- Add to higher level element
   parentSizer:Add(sizer,1,wx.wxEXPAND)

   -- Register widget handle for worker thread
   appWorkerThread.registerHandle("logOutput", logOutput)

   -- Connect events
   logOutput:Connect(
      wx.wxEVT_THREAD,
      function(event)
	 -- simply append all strings from received event
	 logOutput:AppendText(event:GetString())
      end
   )

end

return appLogWidgets
