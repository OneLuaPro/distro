/*
  --------------------------------------------------------------------------------
  MIT License

  core.c - Copyright (c) 2026 Kritzel Kratzel for OneLuaPro.

  Permission is hereby granted, free of charge, to any person obtaining a copy of
  this software and associated documentation files (the "Software"), to deal in 
  the Software without restriction, including without limitation the rights to 
  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
  the Software, and to permit persons to whom the Software is furnished to do so,
  subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all 
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

  --------------------------------------------------------------------------------
*/

#include <windows.h>
#include <softpub.h>
#include <lua.h>
#include <lauxlib.h>

// lua_pushfullstring() acts like lua_pushfstring() but supports the full set
// of format specifiers

const char *lua_pushfullstring(lua_State *L, const char *fmt, ...) {
  va_list argp;
  va_start(argp, fmt);

  // Calculate size
  // By using va_copy, portability is maintained, as va_list becomes invalid
  // after use on some architectures.
  va_list argp_copy;
  va_copy(argp_copy, argp);
  int size = vsnprintf(NULL, 0, fmt, argp_copy);
  va_end(argp_copy);

  if (size < 0) {
    va_end(argp);
    luaL_error(L, "String formatting error");
    return NULL;
  }

  // Use Lua buffer with automatic memory management
  luaL_Buffer b;
  char *buffer = luaL_buffinitsize(L, &b, size + 1);

  // Write to buffer
  vsnprintf(buffer, size + 1, fmt, argp);
  va_end(argp);

  // Finalize string and push on stack
  luaL_pushresultsize(&b, size);
  return lua_tostring(L, -1);
}

// Helper function for formatting Windows error messages
static DWORD getWinErrMsg(char **msgBuf, DWORD dwMessageId) {
  DWORD msgLen = FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER |
				FORMAT_MESSAGE_FROM_SYSTEM |
				FORMAT_MESSAGE_IGNORE_INSERTS,
				NULL,
				dwMessageId,
				MAKELANGID(LANG_ENGLISH, SUBLANG_ENGLISH_US),
				(LPSTR)msgBuf,
				0, NULL);
  // Remove possible line terminations
  if (msgLen > 0 && *msgBuf != NULL) {
    char *ptr = *msgBuf;
    while (msgLen > 0 && (ptr[msgLen - 1] == '\n' || ptr[msgLen - 1] == '\r')) {
      ptr[--msgLen] = '\0';
    }
  }
  return msgLen;
}

// Verifies a Portable Executables (PE File, like EXE, DLL, SYS, OCX, ...)
// for integrity, authenticity, trust chain & time stamp
static int verifyPE(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
    
  // UTF-8 to UTF-16 conversion
  int len = MultiByteToWideChar(CP_UTF8, 0, path, -1, NULL, 0);
  luaL_Buffer b;
  wchar_t *wpath = (wchar_t*)luaL_buffinitsize(L, &b, len * sizeof(wchar_t));  
  MultiByteToWideChar(CP_UTF8, 0, path, -1, wpath, len);

  // WinVerifyTrust init
  GUID actionGuid = WINTRUST_ACTION_GENERIC_VERIFY_V2;
  WINTRUST_FILE_INFO fileInfo = { sizeof(WINTRUST_FILE_INFO), wpath, NULL, NULL };
  WINTRUST_DATA trustData = { sizeof(WINTRUST_DATA) };
  trustData.dwUIChoice = WTD_UI_NONE;
  trustData.dwUnionChoice = WTD_CHOICE_FILE;
  trustData.pFile = &fileInfo;
  trustData.dwProvFlags = WTD_DISABLE_MD2_MD4 | WTD_CACHE_ONLY_URL_RETRIEVAL;
  trustData.hWVTStateData = NULL;

  // verify file
  LONG result = WinVerifyTrust(NULL, &actionGuid, &trustData);
  // Release Trust-Provider resources
  trustData.dwStateAction = WTD_STATEACTION_CLOSE;
  WinVerifyTrust(NULL, &actionGuid, &trustData);
  // Remove buffer from stack
  luaL_pushresultsize(&b, 0); lua_pop(L, 1);

  if (result == ERROR_SUCCESS) {
    lua_pushboolean(L, 1);	// push result
    lua_pushnil(L);		// no error
  }
  else {
    lua_pushboolean(L, 0);	// push result
    char *msgBuf = NULL;
    // Get Windows error message, US_EN only
    DWORD msgLen = getWinErrMsg(&msgBuf, (DWORD)result);
    if (msgLen > 0) {
      // Push error message on stack
      lua_pushfullstring(L, "WinError 0x%08X : %s", (unsigned int)result, msgBuf);
    }
    else {
      // Fallback for any failure of FormatMessageA() to generate a message
      lua_pushfullstring(L, "0x%08X: Unknown Error", (unsigned int)result);
    }    
    // Must do LocalFree() as of FORMAT_MESSAGE_ALLOCATE_BUFFER flag
    if (msgBuf != NULL) LocalFree(msgBuf);
  }
  return 2;
}

// Read digersts from DLL
static int getHashes(lua_State *L) {
  const char *dllPath = luaL_checkstring(L, 1);
  // Optional switch: when true: table[path] = hash, else table[hash] = path (Standard)
  int swapKeys = lua_toboolean(L, 2);

  // UTF-8 to UTF-16 conversion
  int len = MultiByteToWideChar(CP_UTF8, 0, dllPath, -1, NULL, 0);
  luaL_Buffer b;
  wchar_t *wpath = (wchar_t*)luaL_buffinitsize(L, &b, len * sizeof(wchar_t));  
  MultiByteToWideChar(CP_UTF8, 0, dllPath, -1, wpath, len);

  // 1. Load DLL as data module
  HMODULE hLib = LoadLibraryExW(wpath, NULL, LOAD_LIBRARY_AS_DATAFILE);
  // Remove buffer from stack
  luaL_pushresultsize(&b, 0); lua_pop(L, 1);
  if (!hLib) {
    lua_pushnil(L);	// no result
    // Push error message on stack
    DWORD result = GetLastError();
    char *msgBuf = NULL;
    // Get Windows error message, US_EN only
    DWORD msgLen = getWinErrMsg(&msgBuf, result);
    if (msgLen > 0) {
      // Push error message on stack
      lua_pushfullstring(L, "WinError 0x%08X : %s", (unsigned int)result, msgBuf);
    }
    else {
      // Fallback for any failure of FormatMessageA() to generate a message
      lua_pushfullstring(L, "0x%08X: Unknown Error", (unsigned int)result);
    }    
    // Must do LocalFree() as of FORMAT_MESSAGE_ALLOCATE_BUFFER flag
    if (msgBuf != NULL) LocalFree(msgBuf);
    return 2;
  }

  // 2. Find ressource 101 (RT_RCDATA)
  // HRSRC hRes = FindResourceA(hLib, MAKEINTRESOURCEA(101), RT_RCDATA);
  HRSRC hRes = FindResourceW(hLib, MAKEINTRESOURCEW(101), (LPCWSTR)RT_RCDATA);
  if (!hRes) {
    FreeLibrary(hLib);
    lua_pushnil(L);
    lua_pushstring(L, "Resource 101 not found in portable executable.");
    return 2;
  }

  DWORD size = SizeofResource(hLib, hRes);
  HGLOBAL hData = LoadResource(hLib, hRes);
  const char *data = (const char*)LockResource(hData);

  // No Ressource data available
  if (!data || size == 0) {
    FreeLibrary(hLib);
    lua_newtable(L);
    return 1;
  }

  // Create Lua table
  lua_newtable(L);

  // Parse linewise in memory
  const char *ptr = data;
  const char *end = data + size;

  while (ptr < end) {
    // Find end of current line
    const char *lineEnd = ptr;
    while (lineEnd < end && *lineEnd != '\r' && *lineEnd != '\n') {
      lineEnd++;
    }

    // Process line if not empty
    if (lineEnd > ptr) {
      // Look for separator " *"
      const char *sep = NULL;
      for (const char *s = ptr; s < lineEnd - 1; s++) {
	if (s[0] == ' ' && s[1] == '*') {
	  sep = s;
	  break;
	}
      }

      if (sep) {
	size_t hashLen = (size_t)(sep - ptr);
        const char *pathStart = sep + 2;
        size_t pathLen = (size_t)(lineEnd - pathStart);

        if (swapKeys) {
          // table[path] = hash
          lua_pushlstring(L, pathStart, pathLen);
          lua_pushlstring(L, ptr, hashLen);
        }
	else {
          // table[hash] = path (Standard)
          lua_pushlstring(L, ptr, hashLen);
          lua_pushlstring(L, pathStart, pathLen);
        }
	
	// Set table: table[key] = value
	lua_settable(L, -3);
      }
    }

    // Move pointer behind line break
    ptr = lineEnd;
    while (ptr < end && (*ptr == '\r' || *ptr == '\n')) {
      ptr++;
    }
  }

  // Unload DLL
  FreeLibrary(hLib);

  return 1;
}

static const struct luaL_Reg core_funcs [] = {
  {"verify", verifyPE},
  {"getHashes", getHashes},
  {NULL, NULL}
};

LUALIB_API int luaopen_distro_core(lua_State *L){
  luaL_newlib(L, core_funcs);
  return 1;
}
