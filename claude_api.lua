-- Claude API client for OpenComputers
-- Handles communication with Anthropic's Claude API
-- Uses libtls13 for TLS 1.3 support

local component = require("component")
local event = require("event")
local json = require("json")

-- TLS library (libtls13)
local tls = require("tls13")

local api = {}

local API_HOST = "api.anthropic.com"
local API_PORT = 443
local API_PATH = "/v1/messages"
local API_VERSION = "2023-06-01"

-- Check if internet card is available
function api.checkInternet()
  if not component.isAvailable("internet") then
    return false, "No internet card found. Please install an Internet Card."
  end
  if not component.isAvailable("data") then
    return false, "No data card found. TLS requires a T2+ Data Card."
  end
  return true
end

-- Create raw TCP socket and wait for connection
local function createSocket(host, port, timeout)
  local internet = component.internet
  local sock, err = internet.connect(host, port)

  if not sock then
    return nil, "Failed to create socket: " .. tostring(err)
  end

  timeout = timeout or 30
  local startTime = os.time()

  while true do
    local connected, connectErr = sock.finishConnect()
    if connected then
      return sock
    end
    if connected == nil then
      return nil, "Connection failed: " .. tostring(connectErr)
    end
    if os.time() - startTime > timeout then
      sock.close()
      return nil, "Connection timeout"
    end
    os.sleep(0.1)
  end
end

-- Build HTTP request string
local function buildHttpRequest(method, path, host, headers, body)
  local lines = {
    method .. " " .. path .. " HTTP/1.1",
    "Host: " .. host,
  }

  for key, value in pairs(headers) do
    table.insert(lines, key .. ": " .. value)
  end

  if body then
    table.insert(lines, "Content-Length: " .. #body)
  end

  table.insert(lines, "Connection: close")
  table.insert(lines, "")

  if body then
    table.insert(lines, body)
  else
    table.insert(lines, "")
  end

  return table.concat(lines, "\r\n")
end

-- Parse HTTP response
local function parseHttpResponse(data)
  -- Split headers and body
  local headerEnd = data:find("\r\n\r\n")
  if not headerEnd then
    return nil, "Invalid HTTP response: no header/body separator"
  end

  local headerSection = data:sub(1, headerEnd - 1)
  local body = data:sub(headerEnd + 4)

  -- Parse status line
  local statusLine = headerSection:match("^([^\r\n]+)")
  local httpVersion, statusCode, statusMessage = statusLine:match("^(HTTP/%d%.%d)%s+(%d+)%s*(.*)")

  if not statusCode then
    return nil, "Invalid HTTP status line: " .. tostring(statusLine)
  end

  -- Parse headers
  local headers = {}
  for line in headerSection:gmatch("[^\r\n]+") do
    local key, value = line:match("^([^:]+):%s*(.+)$")
    if key then
      headers[key:lower()] = value
    end
  end

  -- Handle chunked transfer encoding
  if headers["transfer-encoding"] and headers["transfer-encoding"]:lower() == "chunked" then
    local decoded = {}
    local pos = 1
    while pos <= #body do
      -- Read chunk size (hex)
      local chunkSizeEnd = body:find("\r\n", pos)
      if not chunkSizeEnd then break end
      local chunkSizeHex = body:sub(pos, chunkSizeEnd - 1)
      local chunkSize = tonumber(chunkSizeHex, 16)
      if not chunkSize or chunkSize == 0 then break end

      -- Read chunk data
      local chunkStart = chunkSizeEnd + 2
      local chunkEnd = chunkStart + chunkSize - 1
      table.insert(decoded, body:sub(chunkStart, chunkEnd))

      -- Move past chunk and trailing CRLF
      pos = chunkEnd + 3
    end
    body = table.concat(decoded)
  end

  return {
    statusCode = tonumber(statusCode),
    statusMessage = statusMessage,
    headers = headers,
    body = body
  }
end

-- Make a request to Claude API using TLS 1.3
function api.sendMessage(apiKey, model, messages, systemPrompt, maxTokens)
  -- Create TCP socket
  local sock, err = createSocket(API_HOST, API_PORT)
  if not sock then
    return nil, err
  end

  -- Wrap socket with TLS using OpenComputers profile (required for key exchange)
  local tlsSock, tlsErr = tls.wrap(sock, tls.profiles.opencomputers, {
    serverName = API_HOST,
    alpnProtocol = "http/1.1"
  })

  if not tlsSock then
    sock.close()
    return nil, "TLS handshake failed: " .. tostring(tlsErr)
  end

  -- Build request body
  local body = {
    model = model,
    max_tokens = maxTokens or 4096,
    messages = messages
  }

  if systemPrompt and systemPrompt ~= "" then
    body.system = systemPrompt
  end

  local jsonBody = json.encode(body)

  -- Build headers
  local headers = {
    ["Content-Type"] = "application/json",
    ["x-api-key"] = apiKey,
    ["anthropic-version"] = API_VERSION
  }

  -- Build and send HTTP request
  local httpRequest = buildHttpRequest("POST", API_PATH, API_HOST, headers, jsonBody)

  local writeOk, writeErr = tlsSock:write(httpRequest)
  if not writeOk then
    tlsSock:close()
    return nil, "Failed to send request: " .. tostring(writeErr)
  end

  -- Read response
  local responseChunks = {}
  local readTimeout = 120 -- seconds for reading (Claude can be slow)
  local startTime = os.time()

  while true do
    local chunk, readErr = tlsSock:read()

    if chunk then
      table.insert(responseChunks, chunk)
      startTime = os.time() -- Reset timeout on data received
    elseif readErr then
      -- Check if it's a close alert (normal end of connection)
      local errStr = tostring(readErr)
      if errStr:find("close") or errStr:find("Close") then
        break
      end
      -- Other error
      if #responseChunks == 0 then
        tlsSock:close()
        return nil, "Read error: " .. errStr
      end
      break
    else
      -- No data available, check timeout
      if os.time() - startTime > readTimeout then
        tlsSock:close()
        return nil, "Read timeout"
      end
      os.sleep(0.1)
    end
  end

  tlsSock:close()

  local responseData = table.concat(responseChunks)

  if #responseData == 0 then
    return nil, "Empty response from server"
  end

  -- Parse HTTP response
  local response, parseErr = parseHttpResponse(responseData)
  if not response then
    return nil, parseErr
  end

  if response.statusCode ~= 200 then
    local errorMsg = "API error " .. response.statusCode .. ": " .. (response.statusMessage or "")
    -- Try to parse error details
    local success, errorData = pcall(json.decode, response.body)
    if success and errorData and errorData.error then
      errorMsg = errorMsg .. " - " .. tostring(errorData.error.message or errorData.error.type)
    end
    return nil, errorMsg
  end

  -- Parse JSON response
  local success, responseJson = pcall(json.decode, response.body)
  if not success then
    return nil, "Failed to parse response: " .. tostring(responseJson)
  end

  return responseJson
end

-- Extract text content from API response
function api.extractContent(response)
  if not response or not response.content then
    return nil, "Invalid response format"
  end

  local textParts = {}
  for _, block in ipairs(response.content) do
    if block.type == "text" then
      table.insert(textParts, block.text)
    end
  end

  return table.concat(textParts, "\n")
end

-- Simple chat function that handles the full flow
function api.chat(config, messages)
  local ok, err = api.checkInternet()
  if not ok then
    return nil, err
  end

  if not config.api_key or config.api_key == "" then
    return nil, "API key not configured. Run 'claude --setup' first."
  end

  local response, apiErr = api.sendMessage(
    config.api_key,
    config.model,
    messages,
    config.system_prompt,
    config.max_tokens
  )

  if not response then
    return nil, apiErr
  end

  local content, extractErr = api.extractContent(response)
  if not content then
    return nil, extractErr
  end

  return content, nil, response
end

return api
