local appWorkerThread = {}

local lanes = require("lanes").configure()
local wx = require("wx")
local bridge = require("wxLanesBridge").init(wx.wxEVT_THREAD)

local handles = {}
local values = {}

function appWorkerThread.registerHandle(key, value)
   -- registers GUI handles which may receive thread events
   handles[key] = value
end

function appWorkerThread.registerValues(key, value)
   -- registers GUI values which are used inside worker thread
   values[key] = value
end

local function task(logWinPtr,btnPtr,sbPtr,dllPath,rootPath,
		    passfailDllPtr)
   -- this is what the thread shall do
   local b = require "wxLanesBridge"
   local dc = require("distro.core")
   local lfs = require("lfs")
   local openssl = require("openssl")
   local tablex = require("pl.tablex")
   -- helper func to redirect thread output to receiving widget logOutput
   local function  printf(fmt,...)
      b.postEvent(logWinPtr,{s=fmt:format(...)})
   end
   -- commonly used outtro steps
   local function outtro()
      b.postEvent(btnPtr,{i=1})	-- enable runButton
      b.postEvent(sbPtr,{s="Idle"})
      printf("")
      -- FIXME
      -- Add trigger to display final resutl here...
   end
   local dllOk, errmsg, dllDigests

   -- Intro: GUI-Update runButton and statusBar
   b.postEvent(btnPtr,{i=0})	-- disable runButton
   b.postEvent(sbPtr,{s="Running"})

   -- Step 1: Check integrity of chksum.dll at OneLuaPro base installation folder
   printf("Checking integrity of %s : ",dllPath)
   dllOk, errmsg = dc.verify(dllPath)
   if dllOk then
      printf("PASS\n")
      b.postEvent(passfailDllPtr,{s="PASS",i=1})
   else
      printf("FAIL : Error message : %s\n",errmsg)
      b.postEvent(passfailDllPtr,{s="FAIL",i=0})
      outtro()
      return
   end

   -- Step 2: Read checksums from DLL - these are the set values. If successful,
   -- the values in dllDigests are the relative paths with "\" as path separator
   printf("Reading SHA256 set values from %s : ",dllPath)
   dllDigests, errmsg = dc.getHashes(dllPath, true) -- table[path] = hash
   if dllDigests then
      printf("DONE\n")
   else
      printf("FAIL : Error message : %s\n",errmsg)
      outtro()
      return
   end

   -- Step 3: Recursive directory traversal from start with concurrent SHA256
   -- calculation
   printf("Calculating SHA256 values from start directory %s : ",rootPath)
   local digest = openssl.digest.new("SHA256")
   local cntFiles = 0
   -- prefixPattern to remove leading installation path prefix
   local prefixPattern = "^" .. (rootPath.."\\"):gsub("\\", "%%\\")	-- constant
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

   local fileList = getFilesRecursive(rootPath)
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

   -- DEBUG
   printf("passCnt               = %d\n",passCnt)
   printf("failCnt               = %d\n",failCnt)
   printf("onlyOnDiskCnt         = %d\n",onlyOnDiskCnt)
   printf("onlyInHashCnt         = %d\n",onlyInHashCnt)
   printf("lockedByOtherProcsCnt = %d\n",lockedByOtherProcsCnt)


   -- Outtro: GUI-Update runButton and statusBar
   outtro()
end

function appWorkerThread.run()
   -- Get the raw C++ pointer to the wxWidget to send events to
   local logOutputPtr = bridge.getPointer(handles["logOutput"])
   local runButtonPtr = bridge.getPointer(handles["runButton"])
   local statusBarPtr = bridge.getPointer(handles["statusBar"])
   local passfailDllPtr = bridge.getPointer(handles["passfailDll"])
   local dllPath = values["dllPath"]
   local rootPath = values["rootPath"]

   -- Generate the Lane and pass the current environment paths so it can find the DLLs
   local worker = lanes.gen("*", {package={path=package.path, cpath=package.cpath}}, task)
   -- local worker = lanes.gen("*", task)

   -- Start the background thread
   worker(logOutputPtr,runButtonPtr,statusBarPtr,dllPath,rootPath,
	  passfailDllPtr)
end

return appWorkerThread
