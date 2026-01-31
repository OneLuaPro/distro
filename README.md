# distro
OneLuaPro distribution information and installation verification

**distro** was specifically developed for [OneLuaPro](https://github.com/OneLuaPro) to provide users with a way to determine the current version of the distribution. With the release of v5.4.8.3, OneLuaPro includes the **DistroCheck** utility, which can be used to verify the integrity of the OneLuaPro installation. 

## DistroCheck

**DistroCheck** cross-references all files within the OneLuaPro installation against SHA-256 checksums generated during the build process of the various OneLuaPro installers. This ensures the detection of any corrupted, modified, or missing data.

### Core Security & Integrity Features

- **Automated Integrity Verification**: DistroCheck ensures that every core component matches the official specification, preventing execution on compromised or incomplete installations.
- **Advanced Tamper Detection**: Instantly identifies unauthorized modifications, malicious injections, or unintended changes to core libraries and the directory structure.
- **Cryptographic Hash-based Validation**: Utilizes industry-standard SHA-256 checksums to guarantee data consistency and eliminate risks from transmission errors or "silent corruption."
- **Reliable Error Diagnosis**: Quickly pinpoint corrupted or missing files to prevent runtime crashes and maintain a stable environment.
- **Secure Offline Validation**: The entire integrity check is performed locally, ensuring privacy and security without requiring an active network connection.
- **Version Compatibility Mapping**: Guarantees that all installed components are perfectly aligned with the detected distribution version for maximum reliability.

### **Deployment & Self-Protection**

DistroCheck is accessible directly from the **Windows Start Menu**. It is written entirely in Lua and leverages the native features and modules of the OneLuaPro installation it is bundled with. To ensure maximum security, DistroCheck itself is tamper-proof: all its internal files are included within the central checksum container. This container is delivered as a **signed DLL**, providing a robust layer of protection against unauthorized manipulation of the verification logic itself.

![DistroCheck GUI Screenshot 1](assets\OLP_DistroCheck01.png)

Simply hit the `Run` button to launch the verification process.

![DistroCheck GUI Screenshot 2](assets\OLP_DistroCheck02.png)

The following screenshot shows an example of a compromised OneLuaPro installation.

![DistroCheck GUI Screenshot 3](assets\OLP_DistroCheck03.png)

## Lua-Module `distro`

The `distro` module provides a straightforward way to query the release version of the installed OneLuaPro distribution.

```lua
local distro = require("distro")
print(distro._VERSION)   -- outputs a string

OneLuaPro 5.4.8.3
```

The following snippet demonstrates a simple check for a minimum required version:

```lua
-- Check OneLuaPro version and require global modules from it
local ok, distro = pcall(require,"distro")
if not ok or distro._VERSION < "OneLuaPro 5.4.8.3" then
   print("\nERROR: This program requires at least OneLuaPro 5.4.8.3.\n")
   os.exit(1)
end
```

> [!WARNING]
>
> Since `_VERSION` is a string, a simple lexical comparison (using `<` or `>`) may yield unexpected results for multi-digit version numbers (e.g., "5.10" being evaluated as smaller than "5.2").

For robust version validation, use a helper function to parse and compare the numeric components:

```lua
local distro = require("distro")

-- Extract numeric components from version string
local function getVersionTable(v_str)
    local t = {}
    for num in v_str:gmatch("%d+") do
        table.insert(t, tonumber(num))
    end
    return t
end

local current = getVersionTable(distro._VERSION)
local required = {5, 4, 8, 3}

local isCompatible = true
for i = 1, #required do
    if (current[i] or 0) < required[i] then
        isCompatible = false
        break
    elseif (current[i] or 0) > required[i] then
        break  -- Current version is newer than required
    end
end

if not isCompatible then
    print("\nERROR: Incompatible version. Found " .. distro._VERSION .. 
          ", but at least 5.4.8.3 is required.\n")
    os.exit(1)
end
```

## License

See `https://github.com/OneLuaPro/distro/blob/master/LICENSE`.
