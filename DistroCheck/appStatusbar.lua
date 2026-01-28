local appStatusbar = {}
local wx = require("wx")
local appWorkerThread = require("DistroCheck.appWorkerThread")

function appStatusbar.create(parent)
   -- create a simple status bar
   parent:CreateStatusBar(2)
   parent:SetStatusWidths({-1, 60})
   parent:SetStatusText("Welcome to DistroCheck 1.0",0)
   parent:SetStatusText("Idle",1)

   -- Register widget handle for worker thread
   appWorkerThread.registerHandle("statusBar", parent)

   parent:Connect(
      wx.wxEVT_THREAD,
      function(event)
	 parent:SetStatusText(event:GetString(),1)
      end
   )

end

return appStatusbar
