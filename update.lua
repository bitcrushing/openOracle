-- Claude Code Updater for OpenComputers
-- Downloads latest files from a remote source

local filesystem = require("filesystem")
local internet = require("internet")
local shell = require("shell")

-- Configuration: Set your base URL here
-- Examples:
--   GitHub raw: "https://raw.githubusercontent.com/USERNAME/REPO/main/"
--   Pastebin: Use individual paste IDs in the files table below
local BASE_URL = "https://raw.githubusercontent.com/USERNAME/REPO/main/"

local INSTALL_DIR = "/usr/lib"
local BIN_DIR = "/usr/bin"

-- Files to update (relative to BASE_URL, or full URLs/paste IDs)
local files = {
  lib = {
    {name = "json.lua", url = "json.lua"},
    {name = "config.lua", url = "config.lua"},
    {name = "claude_api.lua", url = "claude_api.lua"},
    {name = "ui.lua", url = "ui.lua"},
  },
  bin = {
    {name = "claude.lua", url = "claude.lua", destName = "claude"},
  }
}

-- Fetch content from URL
local function fetch(url)
  -- Handle relative URLs
  if not url:match("^https?://") then
    url = BASE_URL .. url
  end

  local content = {}
  local ok, err = pcall(function()
    local handle = internet.request(url)
    if handle then
      for chunk in handle do
        table.insert(content, chunk)
      end
    end
  end)

  if not ok then
    return nil, err
  end

  local result = table.concat(content)
  if #result == 0 then
    return nil, "Empty response"
  end

  return result
end

-- Write content to file
local function writeFile(path, content)
  local file, err = io.open(path, "w")
  if not file then
    return false, err
  end
  file:write(content)
  file:close()
  return true
end

-- Main update function
local function update()
  print("=== Claude Code Updater ===")
  print("")
  print("Source: " .. BASE_URL)
  print("")

  -- Check for internet component
  local component = require("component")
  if not component.isAvailable("internet") then
    print("Error: Internet Card required!")
    return false
  end

  local updated = 0
  local failed = 0

  -- Update library files
  print("Updating libraries...")
  for _, file in ipairs(files.lib) do
    io.write("  " .. file.name .. "... ")
    local content, err = fetch(file.url)
    if content then
      local dst = filesystem.concat(INSTALL_DIR, file.name)
      if filesystem.exists(dst) then
        filesystem.remove(dst)
      end
      local ok, writeErr = writeFile(dst, content)
      if ok then
        print("OK")
        updated = updated + 1
      else
        print("WRITE FAILED: " .. tostring(writeErr))
        failed = failed + 1
      end
    else
      print("FETCH FAILED: " .. tostring(err))
      failed = failed + 1
    end
  end

  -- Update binary files
  print("Updating executables...")
  for _, file in ipairs(files.bin) do
    io.write("  " .. (file.destName or file.name) .. "... ")
    local content, err = fetch(file.url)
    if content then
      local dstName = file.destName or file.name:gsub("%.lua$", "")
      local dst = filesystem.concat(BIN_DIR, dstName)
      if filesystem.exists(dst) then
        filesystem.remove(dst)
      end
      local ok, writeErr = writeFile(dst, content)
      if ok then
        print("OK")
        updated = updated + 1
      else
        print("WRITE FAILED: " .. tostring(writeErr))
        failed = failed + 1
      end
    else
      print("FETCH FAILED: " .. tostring(err))
      failed = failed + 1
    end
  end

  print("")
  print("Update complete: " .. updated .. " updated, " .. failed .. " failed")

  if failed > 0 then
    print("")
    print("Some files failed to update. Check your BASE_URL configuration.")
  end

  return failed == 0
end

-- Run update
update()
