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

   -- Step 1: Check signature of chksum.dll at OneLuaPro base installation folder
   printf("Checking signature of %s: ",values.dllPath)
   dllOk, errmsg = dc.verify(values.dllPath)
   if dllOk then
      printf("PASS\n")
      b.postEvent(receiver.passfailDll,{s="PASS",i=1})
   else
      printf("FAIL: Error message: %s\n",errmsg)
      b.postEvent(receiver.passfailDll,{s="FAIL",i=0})
      b.postEvent(receiver.finalResult,{s="The Checksum Container is corrupted.",i=0})
      outtro()
      return	-- ends the thread prematurely
   end

   -- Step 2: Read checksums from DLL - these are the set values. If successful,
   -- the values in dllDigests are the relative paths with "\" as path separator
   -- omitting the installation prefix path of OneLuaPro
   printf("Reading SHA256 set values from %s: ",values.dllPath)
   dllDigests, errmsg = dc.getHashes(values.dllPath, true) -- table[path] = hash
   if dllDigests then
      printf("DONE\n")
   else
      printf("FAIL: Error message: %s\n",errmsg)
      b.postEvent(receiver.passfailDll,{s="FAIL",i=0})
      b.postEvent(receiver.finalResult,{s="The Checksum File does not contain Checksums.",i=0})
      outtro()
      return	-- ends the thread prematurely
   end

   -- Step 3: Recursive directory traversal from start to obtain list of all files
   --         in fileList[]
   printf("Scanning directory %s:",values.rootPath)
   b.postEvent(receiver.logGauge,{i=0,l=0}) -- puts gauge into indeterminate (pulsing) mode
   local cntFiles = 0
   -- prefixPattern to remove leading installation path prefix
   local prefixPattern = "^" .. (values.rootPath.."\\"):gsub("\\", "%%\\")	-- constant
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
	       -- File found, save path to table (windos path notation), use relative path only
	       fileList[fullPath:gsub("/", "\\"):gsub(prefixPattern,"")] = 0
	       -- :gsub("/", "\\") ... all slashes to backslashes
	       -- :gsub(prefixPattern,"") ... remove constant path prefix
	       cntFiles = cntFiles + 1
            end
	 end
      end
      return fileList
   end
   -- Run recursive local function
   local fileList = getFilesRecursive(values.rootPath)
   printf(" DONE\n")
   b.postEvent(receiver.logGauge,{i=0,l=cntFiles}) -- puts gauge into progress mode

   -- Step 4: SHA256 calculation
   printf("Calculating SHA256 values from files in directory %s:",values.rootPath)
   local digest = openssl.digest.new("SHA256")
   local lockedByOtherProcs = {}
   local lockedByOtherProcsCnt = 0
   local fileNum = 0
   for entry,_ in pairs(fileList) do
      fileNum = fileNum + 1
      b.postEvent(receiver.logGauge,{i=fileNum,l=cntFiles})
      local file, err = io.open(values.rootPath.."\\"..entry, "rb")
      if file then
	 -- file can be opened
	 digest:reset()
	 while true do
	    -- binary read in 8kB chunks
	    local chunk = file:read(8192)
	    if not chunk then break end
	    digest:update(chunk)
	 end
	 file:close()
	 -- save calculated digest to table
	 fileList[entry] = digest:final()
      else
	 -- file could not be opened, maybe locked by other process
	 lockedByOtherProcsCnt = lockedByOtherProcsCnt + 1
	 -- save errmsg as value to current key
	 lockedByOtherProcs[entry:gsub(prefixPattern,"")] = tostring(err)
      end
   end
   printf(" DONE\n")

   -- Step 5: Compare hashes from all found files with hashes from DLL
   local onlyOnDisk = {}
   local onlyOnDiskCnt = 0
   local passCnt = 0
   local fail = {}
   local failCnt = 0
   printf("Comparing SHA256 values:")
   for path, iHash in pairs(fileList) do
      local sHash = dllDigests[path]
      if sHash == nil then
	 -- file found on disk, but not in DLL hashlist
	 onlyOnDisk[path] = iHash
	 onlyOnDiskCnt = onlyOnDiskCnt + 1
      elseif iHash == sHash then
	 -- file found and hash is correct
	 -- remove from dllDigests table
	 dllDigests[path] = nil
	 passCnt = passCnt + 1
      else
	 -- file found, but hash is incorrect
	 -- remove from dllDigests table
	 fail[path] = {sHash=sHash, iHash=iHash}
	 dllDigests[path] = nil
	 failCnt = failCnt + 1
      end
   end
   -- Possibly remaining entries in dllDigests are onlyInHash and not on disk
   local onlyInHash = dllDigests
   local onlyInHashCnt = tablex.size(onlyInHash)
   -- exclude chksum.dll itself from onlyOnDisk
   if onlyOnDisk["chksum.dll"] then
      onlyOnDisk["chksum.dll"] = nil
      onlyOnDiskCnt = onlyOnDiskCnt -1
   end
   printf(" DONE\n")

   -- Step 6: Output any irregularities to logWindow
   if failCnt > 0 then
      printf("\n")
      printf("+-------------------------------------------+\n")
      printf("| Files not matching expected SHA256 Digest |\n")
      printf("+-------------------------------------------+\n")
      for path, data in pairs(fail) do
	 printf("[FAIL] %s\n",values.rootPath.."\\"..path)
	 printf("       Expected digest: %s\n",data.sHash)
	 printf("       Actual digest  : %s\n",data.iHash)
      end
   end
   if onlyOnDiskCnt > 0 then
      printf("\n")
      printf("+---------------------------------------------+\n")
      printf("| Files on Disk but not in Checksum Container |\n")
      printf("+---------------------------------------------+\n")
      for path, hash in pairs(onlyOnDisk) do
	 printf("[FAIL] %s\n",values.rootPath.."\\"..path)
	 printf("       Actual digest  : %s\n",hash)
      end
   end
   if onlyInHashCnt > 0 then
      printf("\n")
      printf("+---------------------------------------------+\n")
      printf("| Files in Checksum Container but not on Disk |\n")
      printf("+---------------------------------------------+\n")
      for path, hash in pairs(onlyInHash) do
	 printf("[FAIL] %s\n",values.rootPath.."\\"..path)
	 printf("       Expected digest: %s\n",hash)
      end
   end
   if lockedByOtherProcsCnt > 0 then
      printf("\n")
      printf("+---------------------------------+\n")
      printf("| Files locked by other Processes |\n")
      printf("+---------------------------------+\n")
      for path, err in pairs(lockedByOtherProcs) do
	 printf("[FAIL] %s\n",values.rootPath.."\\"..path)
	 printf("       Error message  : %s\n",err)
      end
   end

   -- Step 7: Update summary widgets on GUI with obtained results
   -- We use all capabilities of .postEvent() to ease the update of GUI elements
   -- .s = index of target widget in appSummaryWidgets()
   -- .i = desired color of widget text (-1 = default)
   -- .l = the actual number to be displayed
   b.postEvent(receiver.passCnt,{s="passCnt",i=-1,l=passCnt})
   b.postEvent(receiver.failCnt,{s="failCnt",i=-1,l=failCnt})
   b.postEvent(receiver.onlyOnDiskCnt,{s="onlyOnDiskCnt",i=-1,l=onlyOnDiskCnt})
   b.postEvent(receiver.onlyInHashCnt,{s="onlyInHashCnt",i=-1,l=onlyInHashCnt})
   b.postEvent(receiver.lockedByOtherProcsCnt,{s="lockedByOtherProcsCnt",i=-1,l=lockedByOtherProcsCnt})

   -- Step 7: Calculate final result and post to appResultWidgets
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
