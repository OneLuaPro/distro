local appWorkerThread = {}

local lanes = require("lanes").configure()
local wx = require("wx")
local bridge = require("wxLanesBridge").init(wx.wxEVT_THREAD)

local guiReceivers = {}
local guiValues = {}

function appWorkerThread.registerReceiver(key, value)
   -- registers GUI handles which may receive wxThreadEvents
   -- convert receiver handles to actual c++ addresses
   local ptr = bridge.getPointer(value)
   if not ptr then
      wx.wxMessageBox("A critical Runtime Error has occurred in appWorkerThread.registerReceiver().",
		      "Runtime Error",
		      wx.wxOK + wx.wxICON_ERROR)
      os.exit(1)
   end
   guiReceivers[key] = ptr
end

function appWorkerThread.registerValues(key, value)
   -- registers GUI values which are used inside worker thread
   guiValues[key] = value
end

local function task(receiver, values)
   -- this is what the thread shall do
   local b = require "wxLanesBridge"
   local VERSION = require("distro")._VERSION
   local dc = require("distro.core")
   local lfs = require("lfs")
   local openssl = require("openssl")
   local tablex = require("pl.tablex")
   -- helper func to redirect thread output to receiving widget logOutput
   local function  printf(fmt,...)
      b.postEvent(receiver.logOutput,{s=fmt:format(...)})
   end
   -- commonly used outtro steps
   local function outtro()
      b.postEvent(receiver.runButton,{i=1})	-- enable runButton
      b.postEvent(receiver.statusBar,{s="Idle"})
   end
   local dllOk, errmsg, dllDigests

   -- Intro: GUI-Update runButton and statusBar
   b.postEvent(receiver.runButton,{i=0})	-- disable runButton
   b.postEvent(receiver.statusBar,{s="Running"})

   -- Step 1: Check integrity of chksum.dll at OneLuaPro base installation folder
   printf("Checking integrity of %s : ",values.dllPath)
   dllOk, errmsg = dc.verify(values.dllPath)
   if dllOk then
      printf("PASS\n")
      b.postEvent(receiver.passfailDll,{s="PASS",i=1})
   else
      printf("FAIL : Error message : %s\n",errmsg)
      b.postEvent(receiver.passfailDll,{s="FAIL",i=0})
      b.postEvent(receiver.finalResult,{s="The Checksum Container is corrupted.",i=0})
      outtro()
      return	-- ends the thread prematurely
   end

   -- Step 2: Read checksums from DLL - these are the set values. If successful,
   -- the values in dllDigests are the relative paths with "\" as path separator
   printf("Reading SHA256 set values from %s : ",values.dllPath)
   dllDigests, errmsg = dc.getHashes(values.dllPath, true) -- table[path] = hash
   if dllDigests then
      printf("DONE\n")
   else
      printf("FAIL : Error message : %s\n",errmsg)
      b.postEvent(receiver.passfailDll,{s="FAIL",i=0})
      b.postEvent(receiver.finalResult,{s="The Checksum File does not contain Checksums.",i=0})
      outtro()
      return	-- ends the thread prematurely
   end

   -- Step 3: Recursive directory traversal from start with concurrent SHA256
   -- calculation
   printf("Calculating SHA256 values from start directory %s : ",values.rootPath)
   local digest = openssl.digest.new("SHA256")
   local cntFiles = 0
   -- prefixPattern to remove leading installation path prefix
   local prefixPattern = "^" .. (values.rootPath.."\\"):gsub("\\", "%%\\")	-- constant
   local lockedByOtherProcs = {}
   local lockedByOtherProcsCnt = 0
   -- define recursive function
   local function getFilesRecursive(path, fileList)
      fileList = fileList or {}
      -- Iterate over current path
      for entry in lfs.dir(path) do
	 if entry ~= "." and entry ~= ".." then
            local fullPath = path .. "/" .. entry
            local attr = lfs.attributes(fullPath)
            if attr.mode == "directory" then
	       -- Recursion over subdirectory
	       getFilesRecursive(fullPath, fileList)
            elseif attr.mode == "file" then
	       -- Remove leading "./" if present
	       local cleanPath = fullPath:gsub("^%./", "")
	       local file, err = io.open(cleanPath, "rb")
	       if file then
		  -- file exists and can be opened
		  digest:reset()
		  while true do
		     -- binary read in 8kB chunks
		     local chunk = file:read(8192)
		     if not chunk then break end
		     digest:update(chunk)
		  end
		  file:close()
		  -- save to table (windos path notation)
		  -- table[path] = hash
		  -- save relative path as key
		  -- :gsub("/", "\\") ... all slashes to backslashes
		  -- :gsub(prefixPattern,"") ... remove constant path prefix
		  fileList[cleanPath:gsub("/", "\\"):gsub(prefixPattern,"")] = digest:final()
		  -- FIXME: Add Spinner here? {"|", "/", "-", "\\"}
		  cntFiles = cntFiles + 1
		  if cntFiles%50 == 0 then
		     printf(".")
		  end
	       else
		  -- file could not be opened, maybe locked by other process
		  lockedByOtherProcsCnt = lockedByOtherProcsCnt + 1
		  lockedByOtherProcs[cleanPath:gsub("/", "\\"):gsub(prefixPattern,"")] =
		     tostring(err)
	       end
            end
	 end
      end
      return fileList
   end

   local fileList = getFilesRecursive(values.rootPath)
   printf(" DONE\n")

   -- Step 4: Compare hashes from all found files with hashes from DLL
   local onlyOnDisk = {}
   local onlyOnDiskCnt = 0
   local passCnt = 0
   local failCnt = 0
   for path, iHash in pairs(fileList) do
      local sHash = dllDigests[path]
      if sHash == nil then
	 -- file found on disk, but not in DLL hashlist
	 onlyOnDisk[path] = iHash
	 onlyOnDiskCnt = onlyOnDiskCnt + 1
      elseif iHash == sHash then
	 -- file found and hash is correct
	 printf("[PASS]  %s  %s\n",iHash,path)
	 -- remove from dllDigests table
	 dllDigests[path] = nil
	 passCnt = passCnt + 1
      else
	 -- file found, but hash is incorrect
	 printf("[FAIL]  %s  %s\n",iHash,path)
	 -- remove from dllDigests table
	 dllDigests[path] = nil
	 failCnt = failCnt + 1
      end
   end
   local onlyInHash = dllDigests
   local onlyInHashCnt = tablex.size(onlyInHash)
   -- exclude chksum.dll itself from onlyOnDisk
   if onlyOnDisk["chksum.dll"] then
      onlyOnDisk["chksum.dll"] = nil
      onlyOnDiskCnt = onlyOnDiskCnt -1
   end

   -- Step 5: Update summary widgets on GUI with obtained results
   -- We use all capabilities of .postEvent() to ease the update of GUI elements
   -- .s = index of target widget in appSummaryWidgets()
   -- .i = desired color of widget text (-1 = default)
   -- .l = the actual number to be displayed
   b.postEvent(receiver.passCnt,{s="passCnt",i=-1,l=passCnt})
   b.postEvent(receiver.failCnt,{s="failCnt",i=-1,l=failCnt})
   b.postEvent(receiver.onlyOnDiskCnt,{s="onlyOnDiskCnt",i=-1,l=onlyOnDiskCnt})
   b.postEvent(receiver.onlyInHashCnt,{s="onlyInHashCnt",i=-1,l=onlyInHashCnt})
   b.postEvent(receiver.lockedByOtherProcsCnt,{s="lockedByOtherProcsCnt",i=-1,l=lockedByOtherProcsCnt})

   -- Step 6: Calculate final result and post to appResultWidgets
   if dllOk and failCnt == 0 and onlyOnDiskCnt == 0 and onlyInHashCnt == 0 and
      lockedByOtherProcsCnt == 0 then
      -- all good
      b.postEvent(receiver.finalResult,{s="The "..VERSION.." Software Installation is valid.",i=1})
   else
      b.postEvent(receiver.finalResult,{s="The "..VERSION.." Software Installation is corrupted.",i=0})
   end

   -- Outtro: GUI-Update runButton and statusBar
   outtro()
end

function appWorkerThread.run()
   -- Generate the Lane and pass the current environment paths so it can find the DLLs
   local worker = lanes.gen("*", {package={path=package.path, cpath=package.cpath}}, task)

   -- Start the background thread
   worker(guiReceivers, guiValues)
end

return appWorkerThread
