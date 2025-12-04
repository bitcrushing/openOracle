#!/usr/bin/env lua
-- Claude Code for OpenComputers
-- A conversational AI assistant for Minecraft computers
--
-- Installation:
--   1. Copy all .lua files to /usr/lib/ on your OpenComputers computer
--   2. Copy this file (claude.lua) to /usr/bin/claude
--   3. Run 'claude --setup' to configure your API key
--   4. Run 'claude' to start chatting!

local args = {...}

-- Add lib path for requires
package.path = package.path .. ";/usr/lib/?.lua"

local config = require("config")
local api = require("claude_api")
local ui = require("ui")
local json = require("json")
local filesystem = require("filesystem")
local term = require("term")
local event = require("event")

-- Conversation state
local conversation = {
  messages = {},
  history = {} -- Input history for readline
}

-- Modules to unload on exit (to free memory)
local modulesToUnload = {"config", "claude_api", "ui", "json"}

-- Cleanup function to free memory
local function cleanup()
  -- Clear conversation data
  conversation.messages = nil
  conversation.history = nil
  conversation = nil

  -- Unload custom modules from package.loaded cache
  for _, modName in ipairs(modulesToUnload) do
    package.loaded[modName] = nil
  end

  -- Trigger garbage collection via os.sleep loop (OpenComputers workaround)
  -- GC runs when computer is resumed, os.sleep(0) triggers resume cycles
  for _ = 1, 10 do
    os.sleep(0)
  end
end

-- Handle command line arguments
local function handleArgs()
  if #args == 0 then
    return "chat"
  end

  local arg = args[1]
  if arg == "--setup" or arg == "-s" then
    return "setup"
  elseif arg == "--help" or arg == "-h" then
    return "help"
  elseif arg == "--version" or arg == "-v" then
    return "version"
  else
    -- Treat as initial message
    return "chat", table.concat(args, " ")
  end
end

-- Save conversation to file
local function saveConversation(filename)
  filename = filename or "/tmp/claude_conversation.json"

  local file, err = io.open(filename, "w")
  if not file then
    return false, "Failed to open file: " .. tostring(err)
  end

  file:write(json.encode(conversation.messages))
  file:close()
  return true, filename
end

-- Load conversation from file
local function loadConversation(filename)
  filename = filename or "/tmp/claude_conversation.json"

  if not filesystem.exists(filename) then
    return false, "File not found: " .. filename
  end

  local file, err = io.open(filename, "r")
  if not file then
    return false, "Failed to open file: " .. tostring(err)
  end

  local content = file:read("*a")
  file:close()

  local success, data = pcall(json.decode, content)
  if not success or type(data) ~= "table" then
    return false, "Invalid conversation file"
  end

  conversation.messages = data
  return true, #data .. " messages loaded"
end

-- Process slash commands
local function processCommand(input)
  local cmd = input:match("^/(%S+)")
  local cmdArg = input:match("^/%S+%s+(.+)$")

  if cmd == "help" then
    ui.printHelp()
    return true

  elseif cmd == "clear" then
    conversation.messages = {}
    ui.printSuccess("Conversation cleared.")
    return true

  elseif cmd == "setup" then
    config.setup()
    return true

  elseif cmd == "exit" or cmd == "quit" or cmd == "q" then
    return false, "exit"

  elseif cmd == "save" then
    local success, result = saveConversation(cmdArg)
    if success then
      ui.printSuccess("Saved to: " .. result)
    else
      ui.printError(result)
    end
    return true

  elseif cmd == "load" then
    local success, result = loadConversation(cmdArg)
    if success then
      ui.printSuccess(result)
    else
      ui.printError(result)
    end
    return true

  elseif cmd == "history" then
    if #conversation.messages == 0 then
      ui.printInfo("No messages in history.")
    else
      for i, msg in ipairs(conversation.messages) do
        local role = msg.role == "user" and "You" or "Claude"
        ui.setColors(msg.role == "user" and ui.colors.green or ui.colors.cyan)
        print(role .. ": " .. msg.content:sub(1, 50) .. (msg.content:len() > 50 and "..." or ""))
        ui.resetColors()
      end
    end
    return true

  else
    ui.printError("Unknown command: /" .. tostring(cmd))
    ui.printInfo("Type /help for available commands.")
    return true
  end
end

-- Main chat function
local function sendChat(userInput)
  -- Add user message to conversation
  table.insert(conversation.messages, {
    role = "user",
    content = userInput
  })

  -- Show thinking indicator
  ui.setColors(ui.colors.yellow)
  io.write("Thinking...")
  ui.resetColors()

  -- Load config and send request
  local cfg = config.load()
  local response, err, rawResponse = api.chat(cfg, conversation.messages)

  -- Clear thinking indicator
  io.write("\r            \r")

  if not response then
    -- Remove failed message from history
    table.remove(conversation.messages)
    ui.printError(err)
    return false
  end

  -- Add assistant response to conversation
  table.insert(conversation.messages, {
    role = "assistant",
    content = response
  })

  -- Display response
  ui.printResponseLabel()
  ui.printResponse(response)
  print("")

  return true
end

-- Main loop
local function mainLoop(initialMessage)
  ui.clear()
  ui.printHeader()

  -- Check for API key
  local cfg = config.load()
  if not cfg.api_key or cfg.api_key == "" then
    ui.printError("API key not configured.")
    ui.printInfo("Run 'claude --setup' or type /setup to configure.")
    print("")
  end

  -- Check for internet card
  local hasInternet, internetErr = api.checkInternet()
  if not hasInternet then
    ui.printError(internetErr)
    return
  end

  ui.printInfo("Type /help for commands, /exit to quit.")
  print("")

  -- Handle initial message if provided
  if initialMessage and initialMessage ~= "" then
    ui.printPrompt()
    print(initialMessage)
    sendChat(initialMessage)
  end

  -- Main input loop
  while true do
    ui.printPrompt()
    local input = ui.readInput(conversation.history)

    if not input or input == "" then
      -- Empty input, just continue
    elseif input:sub(1, 1) == "/" then
      -- Process command
      local continue, action = processCommand(input)
      if action == "exit" then
        ui.printInfo("Goodbye!")
        break
      end
    else
      -- Add to input history
      table.insert(conversation.history, input)

      -- Send message to Claude
      sendChat(input)
    end
  end
end

-- Print version info
local function printVersion()
  print("Claude Code for OpenComputers v1.0.0")
  print("Powered by Anthropic's Claude API")
end

-- Print usage help
local function printUsage()
  print("Usage: claude [options] [message]")
  print("")
  print("Options:")
  print("  --setup, -s    Configure API key and settings")
  print("  --help, -h     Show this help message")
  print("  --version, -v  Show version information")
  print("")
  print("Examples:")
  print("  claude                   Start interactive chat")
  print("  claude --setup           Configure settings")
  print("  claude \"Hello Claude!\"   Start with a message")
end

-- Entry point
local function main()
  local mode, initialMessage = handleArgs()

  if mode == "setup" then
    config.setup()
  elseif mode == "help" then
    printUsage()
  elseif mode == "version" then
    printVersion()
  elseif mode == "chat" then
    -- Wrap in pcall for clean exit on Ctrl+C
    local ok, err = pcall(mainLoop, initialMessage)
    if not ok and err and not err:match("interrupted") then
      ui.printError(err)
    end
  end

  -- Clean up memory before exit
  cleanup()
end

main()
