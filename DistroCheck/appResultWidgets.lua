local appResultWidgets = {}
local wx = require("wx")

function appResultWidgets.create(parentSizer)

   -- Create elements
   local label = wx.wxStaticText(parentSizer:GetStaticBox(), wx.wxID_ANY,
				 "nil",
				 wx.wxDefaultPosition,wx.wxDefaultSize,wx.wxALIGN_CENTRE)
   -- Create sizer and add elements
   local sizer = wx.wxBoxSizer(wx.wxVERTICAL)
   sizer:Add(label,1,wx.wxEXPAND + wx.wxALL,5)
   -- Add to higher level element
   parentSizer:Add(sizer,1,wx.wxEXPAND)
end

return appResultWidgets
