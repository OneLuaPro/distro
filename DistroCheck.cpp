#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winbase.h>
#include <stdlib.h>
#include <stdio.h>
#include <shlwapi.h>
#include <string>
#include <vector>

#ifdef USE_PATHCCH
// newer, but incompatible with Win7 due to missing api-ms-win-core-path-l1-1-0.dll
#include <pathcch.h>
#define MAX_PATH_BUFFER PATHCCH_MAX_CCH
#else
// older, but compatible with Win7
#include <shlwapi.h>
#define MAX_PATH_BUFFER 32768 // same as PATHCCH_MAX_CCH
#endif

#include <lua.hpp>

#define appName TEXT("DistroCheck.exe")

// Helper function WideCharToUTF8()
static std::string WideCharToUTF8(LPCWSTR text) {
  if (!text) return std::string();
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, text, -1, NULL, 0, NULL, NULL);
  if (size_needed <= 0) return std::string();
  std::vector<char> buffer(size_needed);
  WideCharToMultiByte(CP_UTF8, 0, text, -1, buffer.data(), size_needed, NULL, NULL);
  return std::string(buffer.data());
}

// Define Lua-function to set the package paths ...
static const char *setPaths = R"(
function setPaths(basePath,paths,cpaths)
   local cleanBasePath = basePath:gsub("\\+$", "")
   local fullPaths = {}
   for _,v in ipairs(paths) do
      table.insert(fullPaths,cleanBasePath.."\\"..((v:gsub("^\\+", "")):gsub("\\+$", "")))
   end
   package.path = table.concat(fullPaths,";")
   local fullCpaths = {}
   for _,v in ipairs(cpaths) do
      table.insert(fullCpaths,cleanBasePath.."\\"..((v:gsub("^\\+", "")):gsub("\\+$", "")))
   end
   package.cpath = table.concat(fullCpaths,";")
end
)";
// ... in one string via C++11 Raw String Literals

// Define content for package.path()
static const char* LUA_PATHS[] = {
    R"(bin\lua\?.lua)",
    R"(bin\lua\?\init.lua)",
    R"(bin\?.lua)",
    R"(bin\?\init.lua)",
    "share\\lua\\" LUA_VERSION_MAJOR "." LUA_VERSION_MINOR "\\?.lua",
    "share\\lua\\" LUA_VERSION_MAJOR "." LUA_VERSION_MINOR "\\?\\init.lua",
    R"(.\?.lua)",
    R"(.\?\init.lua)",
    R"(opt\DistroCheck\?.lua)",
    NULL
};

// Define content for package.cpath()
static const char* LUA_CPATHS[] = {
  R"(bin\?.dll)",
  "lib\\lua\\" LUA_VERSION_MAJOR "." LUA_VERSION_MINOR "\\?.dll",
  R"(bin\loadall.dll)",
  R"(.\?.dll)",
  NULL
};

static void SetupDeterministicDllResolution(){
  /* DETERMINISTIC DLL RESOLUTION FOR ONELUAPRO:
   * To keep the '/bin' directory clean, we do not load 'lua.dll' from there.
   * Instead, we redirect the search to 'lib/lua/<MAJOR>.<MINOR>/'.
   *
   * IMPORTANT ARCHITECTURAL NOTE:
   * This requires the executable to be linked with the '/DELAYLOAD:lua.dll'
   * linker option and against 'delayimp.lib'.
   * Delay-loading ensures that the process starts FIRST, allowing this
   * code to set the custom search path BEFORE the OS tries to find the DLL.
   *
   * This guarantees that the interpreter and all DLL-plugins share the exact
   * same DLL instance, which is e.g. critical for thread-pool stability. */
  wchar_t exePath[MAX_PATH_BUFFER];
  if (GetModuleFileNameW(NULL, exePath, MAX_PATH_BUFFER) > 0) {
    wchar_t *lastSlash = wcsrchr(exePath, L'\\');
    if (lastSlash) {
      /* Strip executable name (e.g., 'lua.exe') to get the base '/bin' folder */
      *lastSlash = L'\0';
      /* Construct the relative path to the versioned library folder.
       * The LUAI_TOWSTR macros inject the version numbers from 'lua.h' at
       * compile time. */
      wchar_t dllDir[MAX_PATH_BUFFER];
      _snwprintf(dllDir, MAX_PATH_BUFFER,
		 L"%s\\..\\..\\lib\\lua\\"
		 LUAI_TOWSTR(LUA_VERSION_MAJOR_N)
		 L"."
		 LUAI_TOWSTR(LUA_VERSION_MINOR_N),exePath);
      /* Inject custom search path at the top of the DLL search order.
       * Since lua.dll is delay-loaded, it will be successfully
       * found in the version-specific sub-directory. */
      SetDllDirectoryW(dllDir);
    }
  }
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nShowCmd) {

  // Modity DLL search path
  SetupDeterministicDllResolution();

  // Enable console output although in /SUBSYSTEM:WINDOWS and not in /SUBSYSTEM:CONSOLE
  // https://speedyleion.github.io/c/c++/windows/2021/07/11/WinMain-and-stdout.html
  if(!GetStdHandle(STD_OUTPUT_HANDLE)){
    if(AttachConsole(ATTACH_PARENT_PROCESS)){
      FILE* fp;
      freopen_s(&fp, "CONOUT$","wb",stdout);
      freopen_s(&fp, "CONOUT$","wb",stderr);
    }
  }

  // Get base path of OneLuaPro distribution, assuming a fixed place of DistroCheck.exe
  // within this directory tree under <INSTALL_PREFIX>/opt/DistroCheck
  WCHAR installPrefix[MAX_PATH_BUFFER];
  if (!GetModuleFileNameW(NULL, installPrefix, MAX_PATH_BUFFER)) {
    MessageBox(NULL,
	       TEXT("Couldn't find the path to " appName),
	       TEXT("Failed to start " appName),
	       MB_OK|MB_ICONERROR);
    return 1;
  }
#ifdef USE_PATHCCH
  PathCchRemoveFileSpec(installPrefix,MAX_PATH_BUFFER);
  // remove /opt/DistroCheck from path in installPrefix...
  PathCchRemoveFileSpec(installPrefix,MAX_PATH_BUFFER);
  PathCchRemoveFileSpec(installPrefix,MAX_PATH_BUFFER);
  // ... to yield OneLuaPro (variable) base install directory
  // printf("Base path in installPrefix = %ls\n",installPrefix);
#else
  PathRemoveFileSpecW(installPrefix);
  SetCurrentDirectoryW(installPrefix);
  PathRemoveFileSpecW(installPrefix);
  PathRemoveFileSpecW(installPrefix);
#endif
  std::string utf8Prefix = WideCharToUTF8(installPrefix);

  // Create Lua state
  lua_State *L = luaL_newstate();
  if (!L) {
    MessageBox(NULL,
	       TEXT("Couldn't create a new Lua state."),
	       TEXT("Failed to start " appName),
	       MB_OK|MB_ICONERROR);
    return 1;
  }

  // Load standard libs
  luaL_openlibs(L);

  // Globally register custom function setPaths()
  luaL_dostring(L,setPaths);

  // Put setPaths() on stack - it expects three arguments
  lua_getglobal(L, "setPaths");

  // Push 1st arg on stack - installPrefix
  lua_pushstring(L, utf8Prefix.c_str());

  // Push 2nd arg path-extension on stack
  lua_newtable(L);
  for (int i = 0; LUA_PATHS[i] != NULL; ++i) {
    lua_pushstring(L, LUA_PATHS[i]);
    lua_rawseti(L, -2, i + 1);
  }

  // Push 3rd arg cpath-extension on stack
  lua_newtable(L);
  for (int i = 0; LUA_CPATHS[i] != NULL; ++i) {
    lua_pushstring(L, LUA_CPATHS[i]);
    lua_rawseti(L, -2, i + 1);
  }

  // Call setPaths() with 3 input args and no outputs args
  lua_pcall(L, 3, 0, 0); 
  // package-paths are now set for Lua state

  // Set global variable ONELUAPRO_PREFIX to be used in DistroCheck Lua modules
  lua_pushstring(L, utf8Prefix.c_str());
  lua_setglobal(L, "ONELUAPRO_PREFIX"); 
  
  // Determine path to DistroCheck.lua
  std::string scriptPath = utf8Prefix + "\\opt\\DistroCheck\\DistroCheck.lua";

  // Load DistroCheck.lua and run it
  if (luaL_dofile(L, scriptPath.c_str()) != 0) {
    const char* error = lua_tostring(L, -1);
    MessageBoxA(NULL, error, "DistroCheck Error", MB_OK | MB_ICONERROR);
    lua_close(L);
    return 1;
  }

  // Cleanup
  lua_close(L);
  return 0;
}
