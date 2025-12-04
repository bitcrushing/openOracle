-- Claude Code Installer for OpenComputers
-- Run this script to install Claude Code on your computer

local filesystem = require("filesystem")
local shell = require("shell")

local INSTALL_DIR = "/usr/lib"
local BIN_DIR = "/usr/bin"

local files = {
  lib = {"json.lua", "config.lua", "claude_api.lua", "ui.lua"},
  bin = {"claude.lua", "update.lua"}
}

print("=== Claude Code Installer ===")
print("")

-- Get the directory where install.lua is located
local installSource = shell.resolve(".")

-- Check if source files exist
local sourceDir = installSource
print("Installing from: " .. sourceDir)
print("")

-- Create directories if needed
if not filesystem.exists(INSTALL_DIR) then
  print("Creating " .. INSTALL_DIR .. "...")
  filesystem.makeDirectory(INSTALL_DIR)
end

if not filesystem.exists(BIN_DIR) then
  print("Creating " .. BIN_DIR .. "...")
  filesystem.makeDirectory(BIN_DIR)
end

-- Copy library files
print("Installing libraries...")
for _, file in ipairs(files.lib) do
  local src = filesystem.concat(sourceDir, file)
  local dst = filesystem.concat(INSTALL_DIR, file)

  if filesystem.exists(src) then
    if filesystem.exists(dst) then
      filesystem.remove(dst)
    end
    local success = filesystem.copy(src, dst)
    if success then
      print("  + " .. file)
    else
      print("  ! Failed to copy " .. file)
    end
  else
    print("  ? Missing: " .. file)
  end
end

-- Copy and rename main executable
print("Installing executable...")
for _, file in ipairs(files.bin) do
  local src = filesystem.concat(sourceDir, file)
  local dstName = file:gsub("%.lua$", "") -- Remove .lua extension
  local dst = filesystem.concat(BIN_DIR, dstName)

  if filesystem.exists(src) then
    if filesystem.exists(dst) then
      filesystem.remove(dst)
    end
    local success = filesystem.copy(src, dst)
    if success then
      print("  + " .. dstName)
    else
      print("  ! Failed to copy " .. file)
    end
  else
    print("  ? Missing: " .. file)
  end
end

print("")
print("Installation complete!")
print("")
print("Next steps:")
print("  1. Run 'claude --setup' to configure your API key")
print("  2. Run 'claude' to start chatting!")
print("")
print("To update later:")
print("  Edit BASE_URL in /usr/bin/update, then run 'update'")
print("")
print("Note: You need an Internet Card installed in your computer.")
