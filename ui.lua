-- Terminal UI utilities for Claude Code
-- Handles display, input, and formatting

local component = require("component")
local term = require("term")
local event = require("event")

local ui = {}

-- Get terminal dimensions
function ui.getSize()
  local gpu = term.gpu()
  if gpu then
    return gpu.getViewport()
  end
  return 80, 25 -- Default fallback
end

-- Set colors if available
function ui.setColors(fg, bg)
  local gpu = term.gpu()
  if gpu then
    if fg then pcall(gpu.setForeground, fg) end
    if bg then pcall(gpu.setBackground, bg) end
  end
end

-- Reset colors to default
function ui.resetColors()
  local gpu = term.gpu()
  if gpu then
    pcall(gpu.setForeground, 0xFFFFFF)
    pcall(gpu.setBackground, 0x000000)
  end
end

-- Color constants
ui.colors = {
  white = 0xFFFFFF,
  black = 0x000000,
  gray = 0x888888,
  blue = 0x4444FF,
  green = 0x44FF44,
  red = 0xFF4444,
  yellow = 0xFFFF44,
  cyan = 0x44FFFF,
  orange = 0xFF8844
}

-- Print with color
function ui.printColored(text, color)
  ui.setColors(color)
  print(text)
  ui.resetColors()
end

-- Print header/banner
function ui.printHeader()
  local width = ui.getSize()
  local banner = "Claude Code for OpenComputers"
  local padding = math.floor((width - #banner) / 2)

  print("")
  ui.setColors(ui.colors.cyan)
  print(string.rep(" ", padding) .. banner)
  ui.resetColors()
  ui.setColors(ui.colors.gray)
  print(string.rep("-", width))
  ui.resetColors()
  print("")
end

-- Print prompt for user input
function ui.printPrompt()
  ui.setColors(ui.colors.green)
  io.write("> ")
  ui.resetColors()
end

-- Print Claude's response label
function ui.printResponseLabel()
  ui.setColors(ui.colors.cyan)
  print("Claude:")
  ui.resetColors()
end

-- Print error message
function ui.printError(msg)
  ui.setColors(ui.colors.red)
  print("Error: " .. tostring(msg))
  ui.resetColors()
end

-- Print info message
function ui.printInfo(msg)
  ui.setColors(ui.colors.gray)
  print(msg)
  ui.resetColors()
end

-- Print success message
function ui.printSuccess(msg)
  ui.setColors(ui.colors.green)
  print(msg)
  ui.resetColors()
end

-- Word wrap text to fit screen width
function ui.wordWrap(text, maxWidth)
  maxWidth = maxWidth or ui.getSize()
  local lines = {}

  for line in text:gmatch("[^\n]*") do
    if #line <= maxWidth then
      table.insert(lines, line)
    else
      -- Wrap long lines
      local currentLine = ""
      for word in line:gmatch("%S+") do
        if #currentLine + #word + 1 <= maxWidth then
          if currentLine == "" then
            currentLine = word
          else
            currentLine = currentLine .. " " .. word
          end
        else
          if currentLine ~= "" then
            table.insert(lines, currentLine)
          end
          -- Handle very long words
          while #word > maxWidth do
            table.insert(lines, word:sub(1, maxWidth))
            word = word:sub(maxWidth + 1)
          end
          currentLine = word
        end
      end
      if currentLine ~= "" then
        table.insert(lines, currentLine)
      elseif #lines == 0 or lines[#lines] ~= "" then
        table.insert(lines, "")
      end
    end
  end

  return table.concat(lines, "\n")
end

-- Print response with word wrapping and pagination for long messages
function ui.printResponse(text)
  local width, height = ui.getSize()
  local wrapped = ui.wordWrap(text, width - 2)

  -- Split into lines
  local lines = {}
  for line in wrapped:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end

  -- Remove trailing empty line from pattern match
  if lines[#lines] == "" then
    table.remove(lines)
  end

  -- Calculate usable height (reserve 2 lines for prompt)
  local pageSize = height - 4

  -- If fits on screen, just print
  if #lines <= pageSize then
    print(wrapped)
    return
  end

  -- Paginate long responses
  local currentLine = 1
  while currentLine <= #lines do
    -- Print one page
    local endLine = math.min(currentLine + pageSize - 1, #lines)
    for i = currentLine, endLine do
      print(lines[i])
    end

    currentLine = endLine + 1

    -- If more content, show prompt
    if currentLine <= #lines then
      local remaining = #lines - currentLine + 1
      ui.setColors(ui.colors.yellow)
      io.write("-- More (" .. remaining .. " lines) [Enter=next, q=quit] --")
      ui.resetColors()

      -- Wait for keypress
      local _, _, char = event.pull("key_down")
      -- Clear the prompt line
      io.write("\r" .. string.rep(" ", width) .. "\r")

      -- Check for quit
      if char == 113 or char == 81 then -- 'q' or 'Q'
        ui.setColors(ui.colors.gray)
        print("(Response truncated)")
        ui.resetColors()
        break
      end
    end
  end
end

-- Read user input with history support
function ui.readInput(history)
  history = history or {}
  local input = term.read(history, false, nil, nil)
  if input then
    input = input:gsub("%s+$", "") -- Trim trailing whitespace/newline
  end
  return input
end

-- Show a simple spinner while waiting
function ui.showSpinner(message)
  local spinChars = {"|", "/", "-", "\\"}
  local idx = 1
  local running = true

  message = message or "Thinking"

  local function spin()
    while running do
      ui.setColors(ui.colors.yellow)
      io.write("\r" .. message .. " " .. spinChars[idx] .. " ")
      ui.resetColors()
      idx = (idx % #spinChars) + 1
      os.sleep(0.1)
    end
  end

  -- Return control functions
  return {
    stop = function()
      running = false
      io.write("\r" .. string.rep(" ", #message + 3) .. "\r")
    end
  }
end

-- Confirm prompt
function ui.confirm(message)
  ui.setColors(ui.colors.yellow)
  io.write(message .. " (y/n): ")
  ui.resetColors()

  local input = ui.readInput()
  return input and (input:lower() == "y" or input:lower() == "yes")
end

-- Print help information
function ui.printHelp()
  local width = ui.getSize()

  print("")
  ui.printColored("Commands:", ui.colors.cyan)
  print("  /help     - Show this help message")
  print("  /clear    - Clear conversation history")
  print("  /setup    - Configure API settings")
  print("  /exit     - Exit Claude Code")
  print("  /save     - Save conversation to file")
  print("  /load     - Load conversation from file")
  print("  /last     - Re-display last response")
  print("")
  ui.printColored("Tips:", ui.colors.cyan)
  print("  - Press Ctrl+C to interrupt")
  print("  - Use arrow keys for input history")
  print("  - Long responses are paginated (q to skip)")
  print("")
end

-- Clear screen
function ui.clear()
  term.clear()
end

return ui
