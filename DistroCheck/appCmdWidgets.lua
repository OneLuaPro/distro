local appCmdWidgets = {}
local wx = require("wx")
local appWorkerThread = require("DistroCheck.appWorkerThread")
local appLogWidgets = require("DistroCheck.appLogWidgets")
local appSummaryWidgets = require("DistroCheck.appSummaryWidgets")
local appResultWidgets = require("DistroCheck.appResultWidgets")

-- Get OneLuaPro Installation Prefix, e.g. C:\Apps\OneLuaPro
-- Case A:
--    wx.wxStandardPaths.Get():GetDataDir() returns installation folder of lua.exe
--    :match("(.*)[/\\]") returns the rootPath
-- Case B:
--    global var ONELUAPRO_PREFIX is set by launcher executable DistroCheck.exe
-- In any case - DLL path is hard-coded by intention and must not be modified
local rootPath = _G.ONELUAPRO_PREFIX or
   wx.wxStandardPaths.Get():GetDataDir():match("(.*)[/\\]")
local dllPath = rootPath .. "\\chksum.dll"

function appCmdWidgets.create(parentSizer)
   -- Create elements
   local label = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY, "Checksum Container")
   local path  = wx.wxTextCtrl(parentSizer:GetStaticBox(), wx.wxID_ANY, dllPath,
			 wx.wxDefaultPosition, wx.wxDefaultSize,
			 wx.wxTE_READONLY)
   local runButton = wx.wxButton(parentSizer:GetStaticBox(), wx.wxID_ANY, "Run",
				 wx.wxDefaultPosition,wx.wxDefaultSize)

   -- Create sizer and add elements
   local sizer = wx.wxFlexGridSizer(1,3)
   sizer:AddGrowableCol(1,1)
   sizer:Add(label,1,wx.wxEXPAND + wx.wxALL,5)
   sizer:Add(path,1,wx.wxEXPAND + wx.wxALL,5)
   sizer:Add(runButton,1,wx.wxEXPAND + wx.wxALL,5)

   -- Add to higher level element
   parentSizer:Add(sizer,1,wx.wxEXPAND)

   -- Register event receivers and GUI values
   appWorkerThread.registerReceiver("runButton", runButton)
   appWorkerThread.registerValues("dllPath", dllPath)
   appWorkerThread.registerValues("rootPath", rootPath)

   -- Connect events
   runButton:Connect(
      wx.wxEVT_BUTTON,
      function()
	 -- kick-off worker thread
	 appLogWidgets.clear()
	 appSummaryWidgets.reset()
	 appResultWidgets.reset()
	 appWorkerThread.run()
      end
   )
   runButton:Connect(
      wx.wxEVT_THREAD,
      function(event)
	 -- get enabled / disabled by worker thread
	 runButton:Enable(event:GetInt())
      end
   )

end

return appCmdWidgets
