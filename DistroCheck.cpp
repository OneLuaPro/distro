#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winbase.h>
#include <stdlib.h>
#include <stdio.h>
#include <shlwapi.h>
#include <pathcch.h>
#include <string>
#include <vector>

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

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nShowCmd) {

  // Enable console output although in /SUBSYSTEM:WINDOWS and not in /SUBSYSTEM:CONSOLE
  // https://speedyleion.github.io/c/c++/windows/2021/07/11/WinMain-and-stdout.html
  if(!GetStdHandle(STD_OUTPUT_HANDLE)){
    if(AttachConsole(ATTACH_PARENT_PROCESS)){
      freopen("CONOUT$","wb",stdout);
      freopen("CONOUT$","wb",stderr);
    }
  }

  // Get base path of OneLuaPro distribution, assuming a fixed place of DistroCheck.exe
  // within this directory tree under <INSTALL_PREFIX>/opt/DistroCheck
  WCHAR installPrefix[PATHCCH_MAX_CCH];
  if (!GetModuleFileNameW(NULL, installPrefix, PATHCCH_MAX_CCH)) {
    MessageBox(NULL,
	       TEXT("Couldn't find the path to " appName),
	       TEXT("Failed to start " appName),
	       MB_OK|MB_ICONERROR);
    return 1;
  }
  PathCchRemoveFileSpec(installPrefix,PATHCCH_MAX_CCH);
  // remove /opt/DistroCheck from path in installPrefix...
  PathCchRemoveFileSpec(installPrefix,PATHCCH_MAX_CCH);
  PathCchRemoveFileSpec(installPrefix,PATHCCH_MAX_CCH);
  // ... to yield OneLuaPro (variable) base install directory
  // printf("Base path in installPrefix = %ls\n",installPrefix);
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
