local appLayout = {}
local wx = require("wx")
local appCmdWidgets = require("DistroCheck.appCmdWidgets")
local appLogWidgets = require("DistroCheck.appLogWidgets")
local appSummaryWidgets = require("DistroCheck.appSummaryWidgets")
local appResultWidgets = require("DistroCheck.appResultWidgets")


function appLayout.create(parent)

   -- Create elements
   local cmdPanel = wx.wxPanel(parent, wx.wxID_ANY)
   local logPanel = wx.wxPanel(parent, wx.wxID_ANY)
   local summaryPanel = wx.wxPanel(parent, wx.wxID_ANY)
   local resultPanel = wx.wxPanel(parent, wx.wxID_ANY)
   -- Create sizer and add elements
   local parentSizer = wx.wxFlexGridSizer(4,1)
   parentSizer:AddGrowableCol(0,1)
   parentSizer:AddGrowableRow(1,1)
   parentSizer:Add(cmdPanel, 1, wx.wxEXPAND + wx.wxLEFT+wx.wxRIGHT, 5)
   parentSizer:Add(logPanel, 1, wx.wxEXPAND + wx.wxLEFT+wx.wxRIGHT, 5)
   parentSizer:Add(summaryPanel, 1, wx.wxEXPAND + wx.wxLEFT+wx.wxRIGHT, 5)
   parentSizer:Add(resultPanel, 1, wx.wxEXPAND + wx.wxLEFT+wx.wxRIGHT+wx.wxBOTTOM, 5)
   -- Apply sizer to parent
   parent:SetSizer(parentSizer)

   local cmdSizer = wx.wxStaticBoxSizer(wx.wxVERTICAL,cmdPanel, "Command")
   cmdPanel:SetSizer(cmdSizer)
   appCmdWidgets.create(cmdSizer)

   local logSizer = wx.wxStaticBoxSizer(wx.wxVERTICAL,logPanel, "Log")
   logPanel:SetSizer(logSizer)
   appLogWidgets.create(logSizer)

   local summarySizer = wx.wxStaticBoxSizer(wx.wxVERTICAL,summaryPanel, "Summary")
   summaryPanel:SetSizer(summarySizer)
   appSummaryWidgets.create(summarySizer)

   local resultSizer = wx.wxStaticBoxSizer(wx.wxVERTICAL,resultPanel, "Result")
   resultPanel:SetSizer(resultSizer)
   appResultWidgets.create(resultSizer)

   -- Final settings
   parentSizer:SetSizeHints(parent)
   parent:SetAutoLayout(true)
   parent:Layout()

end

return appLayout
