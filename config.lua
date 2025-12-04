-- Configuration handler for Claude Code
-- Manages API keys and settings

local filesystem = require("filesystem")
local json = require("json")

local config = {}

local CONFIG_PATH = "/etc/claude.cfg"
local DEFAULT_CONFIG = {
  api_key = "",
  model = "claude-sonnet-4-20250514",
  max_tokens = 4096,
  system_prompt = "You are Claude, an AI assistant running inside a Minecraft computer (OpenComputers mod). Help the user with their tasks. Keep responses concise as screen space is limited."
}

-- Load configuration from file
function config.load()
  if not filesystem.exists(CONFIG_PATH) then
    return DEFAULT_CONFIG
  end

  local file, err = io.open(CONFIG_PATH, "r")
  if not file then
    return DEFAULT_CONFIG
  end

  local content = file:read("*a")
  file:close()

  local success, cfg = pcall(json.decode, content)
  if not success or type(cfg) ~= "table" then
    return DEFAULT_CONFIG
  end

  -- Merge with defaults
  for k, v in pairs(DEFAULT_CONFIG) do
    if cfg[k] == nil then
      cfg[k] = v
    end
  end

  return cfg
end

-- Save configuration to file
function config.save(cfg)
  -- Ensure /etc directory exists
  if not filesystem.exists("/etc") then
    filesystem.makeDirectory("/etc")
  end

  local file, err = io.open(CONFIG_PATH, "w")
  if not file then
    return false, "Failed to open config file: " .. tostring(err)
  end

  file:write(json.encode(cfg))
  file:close()
  return true
end

-- Get a specific config value
function config.get(key)
  local cfg = config.load()
  return cfg[key]
end

-- Set a specific config value
function config.set(key, value)
  local cfg = config.load()
  cfg[key] = value
  return config.save(cfg)
end

-- Interactive setup for API key
function config.setup()
  local term = require("term")

  term.clear()
  print("=== Claude Code Configuration ===")
  print("")

  local cfg = config.load()

  io.write("API Key")
  if cfg.api_key ~= "" then
    io.write(" [" .. cfg.api_key:sub(1, 10) .. "...]")
  end
  io.write(": ")
  local key = term.read()
  key = key and key:gsub("%s+$", "") or ""

  if key ~= "" then
    cfg.api_key = key
  end

  io.write("Model [" .. cfg.model .. "]: ")
  local model = term.read()
  model = model and model:gsub("%s+$", "") or ""

  if model ~= "" then
    cfg.model = model
  end

  io.write("Max tokens [" .. cfg.max_tokens .. "]: ")
  local tokens = term.read()
  tokens = tokens and tokens:gsub("%s+$", "") or ""

  if tokens ~= "" then
    local num = tonumber(tokens)
    if num then
      cfg.max_tokens = num
    end
  end

  local success, err = config.save(cfg)
  if success then
    print("")
    print("Configuration saved!")
  else
    print("")
    print("Error saving config: " .. tostring(err))
  end

  return cfg
end

return config
