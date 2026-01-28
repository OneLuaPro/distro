-- Distro-Check --
---------------------------------------------------------------------------------
-- Check OneLuaPro version and require global modules from it
local ok, distro = pcall(require,"distro")
if not ok or distro._VERSION < "OneLuaPro 5.4.8.3" then
   print("\nERROR: DistroCheck requires at least OneLuaPro 5.4.8.3.\n")
   os.exit(1)
end
local wx = require("wx")
-- local utils = require("pl.utils")	-- Penlight
-- local path = require("pl.path")		-- Penlight
local appMenue = require("DistroCheck.appMenue")
local appStatusbar = require("DistroCheck.appStatusbar")
local appConfig = require("DistroCheck.appConfig")
local appLayout = require("DistroCheck.appLayout")

local function main()

   -- create parent of everything with custom frame style
   local frame = wx.wxFrame(wx.NULL, wx.wxID_ANY, "OneLuaPro DistroCheck",
			    wx.wxDefaultPosition, wx.wxDefaultSize,
			    wx.wxDEFAULT_FRAME_STYLE) -- - wx.wxRESIZE_BORDER - wx.wxMAXIMIZE_BOX)
   frame:SetBackgroundColour(wx.wxNullColour)	-- change to default UI-gray
   -- Load and set the icon file and other stuff
   local scriptPath = arg[0]
   local scriptDir = scriptPath:match("(.*[/\\])") or "./"
   local iconPath = scriptDir .. "DistroCheck/assets/blocks-icons-msw.ico"
   local icon = wx.wxIcon(iconPath, wx.wxBITMAP_TYPE_ICO)
   frame:SetIcon(icon)
   -- user simply clicked the close main window symbol
   frame:Connect(
      wx.wxEVT_CLOSE_WINDOW,
      function()
	 -- save settings to config
	 appConfig.saveAll()
	 os.exit(0)
      end
   )

   -- create config object
   appConfig.create(frame)
   -- create menue
   appMenue.create(frame)
   -- create UI content
   appLayout.create(frame)
   -- create statusbat
   appStatusbar.create(frame)

   -- Set frame to last size & position
   appConfig.setFrame()
   frame:Show(true)
   collectgarbage("collect")
end
main()
wx.wxGetApp():MainLoop()
