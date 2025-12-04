-- JSON library for OpenComputers
-- Handles encoding/decoding JSON for Claude API communication

local json = {}

-- Encode a Lua value to JSON string
function json.encode(value)
  local t = type(value)

  if value == nil then
    return "null"
  elseif t == "boolean" then
    return value and "true" or "false"
  elseif t == "number" then
    if value ~= value then -- NaN
      return "null"
    elseif value == math.huge then
      return "1e308"
    elseif value == -math.huge then
      return "-1e308"
    else
      return tostring(value)
    end
  elseif t == "string" then
    -- Escape special characters
    local escaped = value:gsub('[\\"\b\f\n\r\t]', function(c)
      local replacements = {
        ['\\'] = '\\\\',
        ['"'] = '\\"',
        ['\b'] = '\\b',
        ['\f'] = '\\f',
        ['\n'] = '\\n',
        ['\r'] = '\\r',
        ['\t'] = '\\t'
      }
      return replacements[c]
    end)
    -- Escape control characters
    escaped = escaped:gsub('[\x00-\x1f]', function(c)
      return string.format('\\u%04x', string.byte(c))
    end)
    return '"' .. escaped .. '"'
  elseif t == "table" then
    -- Check if it's an array or object
    local isArray = true
    local maxIndex = 0
    local count = 0

    for k, _ in pairs(value) do
      count = count + 1
      if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
        isArray = false
        break
      end
      if k > maxIndex then
        maxIndex = k
      end
    end

    if isArray and maxIndex == count then
      -- Encode as array
      local parts = {}
      for i = 1, #value do
        parts[i] = json.encode(value[i])
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      -- Encode as object
      local parts = {}
      for k, v in pairs(value) do
        if type(k) == "string" then
          table.insert(parts, json.encode(k) .. ":" .. json.encode(v))
        end
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  else
    error("Cannot encode type: " .. t)
  end
end

-- Decode a JSON string to Lua value
function json.decode(str)
  local pos = 1

  local function skipWhitespace()
    while pos <= #str do
      local c = str:sub(pos, pos)
      if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
        pos = pos + 1
      else
        break
      end
    end
  end

  local function parseValue()
    skipWhitespace()
    local c = str:sub(pos, pos)

    if c == '"' then
      return parseString()
    elseif c == '{' then
      return parseObject()
    elseif c == '[' then
      return parseArray()
    elseif c == 't' then
      if str:sub(pos, pos + 3) == "true" then
        pos = pos + 4
        return true
      end
    elseif c == 'f' then
      if str:sub(pos, pos + 4) == "false" then
        pos = pos + 5
        return false
      end
    elseif c == 'n' then
      if str:sub(pos, pos + 3) == "null" then
        pos = pos + 4
        return nil
      end
    elseif c == '-' or (c >= '0' and c <= '9') then
      return parseNumber()
    end

    error("Invalid JSON at position " .. pos .. ": " .. str:sub(pos, pos + 20))
  end

  function parseString()
    pos = pos + 1 -- skip opening quote
    local result = {}

    while pos <= #str do
      local c = str:sub(pos, pos)

      if c == '"' then
        pos = pos + 1
        return table.concat(result)
      elseif c == '\\' then
        pos = pos + 1
        local escape = str:sub(pos, pos)
        if escape == '"' then
          table.insert(result, '"')
        elseif escape == '\\' then
          table.insert(result, '\\')
        elseif escape == '/' then
          table.insert(result, '/')
        elseif escape == 'b' then
          table.insert(result, '\b')
        elseif escape == 'f' then
          table.insert(result, '\f')
        elseif escape == 'n' then
          table.insert(result, '\n')
        elseif escape == 'r' then
          table.insert(result, '\r')
        elseif escape == 't' then
          table.insert(result, '\t')
        elseif escape == 'u' then
          local hex = str:sub(pos + 1, pos + 4)
          local codepoint = tonumber(hex, 16)
          if codepoint then
            if codepoint < 128 then
              table.insert(result, string.char(codepoint))
            elseif codepoint < 2048 then
              table.insert(result, string.char(
                192 + math.floor(codepoint / 64),
                128 + (codepoint % 64)
              ))
            else
              table.insert(result, string.char(
                224 + math.floor(codepoint / 4096),
                128 + math.floor((codepoint % 4096) / 64),
                128 + (codepoint % 64)
              ))
            end
          end
          pos = pos + 4
        end
        pos = pos + 1
      else
        table.insert(result, c)
        pos = pos + 1
      end
    end

    error("Unterminated string")
  end

  function parseNumber()
    local startPos = pos

    -- Handle negative
    if str:sub(pos, pos) == '-' then
      pos = pos + 1
    end

    -- Integer part
    while pos <= #str and str:sub(pos, pos):match('[0-9]') do
      pos = pos + 1
    end

    -- Decimal part
    if str:sub(pos, pos) == '.' then
      pos = pos + 1
      while pos <= #str and str:sub(pos, pos):match('[0-9]') do
        pos = pos + 1
      end
    end

    -- Exponent
    local e = str:sub(pos, pos)
    if e == 'e' or e == 'E' then
      pos = pos + 1
      local sign = str:sub(pos, pos)
      if sign == '+' or sign == '-' then
        pos = pos + 1
      end
      while pos <= #str and str:sub(pos, pos):match('[0-9]') do
        pos = pos + 1
      end
    end

    return tonumber(str:sub(startPos, pos - 1))
  end

  function parseArray()
    pos = pos + 1 -- skip [
    local result = {}

    skipWhitespace()
    if str:sub(pos, pos) == ']' then
      pos = pos + 1
      return result
    end

    while true do
      table.insert(result, parseValue())
      skipWhitespace()

      local c = str:sub(pos, pos)
      if c == ']' then
        pos = pos + 1
        return result
      elseif c == ',' then
        pos = pos + 1
      else
        error("Expected ',' or ']' in array")
      end
    end
  end

  function parseObject()
    pos = pos + 1 -- skip {
    local result = {}

    skipWhitespace()
    if str:sub(pos, pos) == '}' then
      pos = pos + 1
      return result
    end

    while true do
      skipWhitespace()
      if str:sub(pos, pos) ~= '"' then
        error("Expected string key in object")
      end

      local key = parseString()
      skipWhitespace()

      if str:sub(pos, pos) ~= ':' then
        error("Expected ':' after object key")
      end
      pos = pos + 1

      result[key] = parseValue()
      skipWhitespace()

      local c = str:sub(pos, pos)
      if c == '}' then
        pos = pos + 1
        return result
      elseif c == ',' then
        pos = pos + 1
      else
        error("Expected ',' or '}' in object")
      end
    end
  end

  local result = parseValue()
  skipWhitespace()

  return result
end

return json
