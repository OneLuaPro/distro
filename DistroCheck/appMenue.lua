---------------------------------------------------------------------------------
-- module appmenue
local appMenue = {}
local wx = require("wx")

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
	 -- local t = {
	 --    "IFA-Cockpit is part of\n\n",
	 --    string.format("%s %s\n",version.getName(), version.getVersion()),
	 --    string.format("(%s / %s)\n\n",version.getMatnum(),version.getPartnum()),
	 --    string.format("%s\n\n",version.getCopyright()),
	 --    -- string.format("IFA-Cockpit uses %s built with %s",
	 --    -- 	      wxlua.wxLUA_VERSION_STRING,wx.wxVERSION_STRING),
	 -- }
	 wx.wxMessageBox("DistroCheck v1.0",
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
