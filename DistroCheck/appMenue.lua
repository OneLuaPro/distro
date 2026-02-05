---------------------------------------------------------------------------------
-- module appmenue
local appMenue = {}
local wx = require("wx")
local distro = require("distro")

function appMenue.create(parent)

   -- Menue File
   local fileMenu = wx.wxMenu()
   -- File -> Exit
   local exitItem = wx.wxMenuItem(fileMenu, wx.wxID_EXIT, "Exit\tCtrl-Q", "Quit the Program")
   local exitIcon = wx.wxArtProvider.GetBitmap(wx.wxART_QUIT, wx.wxART_MENU)
   exitItem:SetBitmap(exitIcon)
   fileMenu:Append(exitItem)
   parent:Connect(
      wx.wxID_EXIT, wx.wxEVT_COMMAND_MENU_SELECTED,
      function ()
	 parent:Close(true)
	 -- Automatically triggers wxEVT_CLOSE_WINDOW event
      end
   )

   -- Menue Help
   local helpMenu = wx.wxMenu()
   -- Help -> About
   local helpItem = wx.wxMenuItem(helpMenu, wx.wxID_ABOUT, "About", "About CheckDistro")
   local helpIcon = wx.wxArtProvider.GetBitmap(wx.wxART_HELP, wx.wxART_MENU)
   helpItem:SetBitmap(helpIcon)
   helpMenu:Append(helpItem)
   parent:Connect(
      wx.wxID_ABOUT, wx.wxEVT_COMMAND_MENU_SELECTED,
      function ()
	 wx.wxMessageBox("DistroCheck for "..distro._VERSION.."\n\n"..
			 "This utility verifies the integrity of the OneLuaPro "..
			 "installation. It cross-references each file against "..
			 "SHA256 checksums generated during the build process to "..
			 "detect corruption or missing data.\n\n"..
			 "Copyright (c) 2026 The OneLuaPro project authors",
			 "About DistroCheck",
			 wx.wxOK + wx.wxICON_INFORMATION,
			 parent)
      end
   )

   -- Create Menu Bar
   local menuBar = wx.wxMenuBar()
   menuBar:Append(fileMenu, "File")
   menuBar:Append(helpMenu, "Help")

   -- Activate the Menu Bar
   parent:SetMenuBar(menuBar)

end
return appMenue
