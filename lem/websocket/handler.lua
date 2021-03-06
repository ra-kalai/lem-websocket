local core = require 'lem.websocket.core'
local base64encode = core.base64encode
local sha1 = core.sha1
local format = string.format
local concat = table.concat
local websocket_frame = core.buildframe

local rfc6455GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

local websocket_metatable = { }
websocket_metatable.__index = websocket_metatable

function websocket_metatable:sendText(payload)
  return self.client:write(websocket_frame(payload, 0x81, self.clientOrServer))
end

function websocket_metatable:sendBinary(payload)
  return self.client:write(websocket_frame(payload, 0x82, self.clientOrServer))
end

function websocket_metatable:ping(payload)
  return self.client:write(websocket_frame(payload, 0x9, self.clientOrServer))
end

-- This function is called once we return from a hathaway hook.
-- no need to take the previous defined function, as headers can't be
-- appended to a websocket connection.
function websocket_metatable:appendheader() end

local closeMsg = {
  [1000] = "\232\3normal closure",
  [1002] = "\232\5protocol error",
}

function websocket_metatable:close(msg)
  if msg == nil then
    msg = closeMsg[1000]
  end

  self.client:write(websocket_frame(msg, 0x88, self.clientOrServer))

  return self.client:close()
end

local reactionOnOpcode = {
  -- continuation
  [0]= function (res, fin, payload)
    if res.continuation == nil then
      return -2, {'continuation of nothing received', payload}
    end

    if fin == 1 then
      res.continuation = nil
      return nil, payload
    else
      local err, npayload = res:getFrame()
      if err then
        return err, npayload
      end
      return nil, payload .. npayload
    end
  end,
  -- text
  [1] = function (res, fin, payload)
    if res.continuation == 1 then
      return -3, {'continuation broken by text frame', payload}
    end

    if fin == 1 then
      res.continuation = nil
      return nil, payload
    else
      self.continuation = 1
      local err, npayload = res:getFrame()
      if err then
        return err, npayload
      end
      return nil, payload .. npayload
    end
  end,
  -- binary
  [2] = function (res, fin, payload)
    if res.continuation == 1 then
      return -3, {'continuation broken by binary frame', payload}
    end

    if fin == 1 then
      res.continuation = nil
      return nil, payload
    else
      res.continuation = 1
      local err, npayload = res:getFrame()
      if err then
        return err, npayload
      end
      return nil, payload .. npayload
    end
  end,
  -- closing
  [8] = function (res, fin, payload)
    res:close(payload)
    return 8, {"disconnect", payload}
  end,
  -- ping
  [9] = function (res, fin, payload)
    -- send a pong
    res.client:write(websocket_frame(payload, 0xA, res.clientOrServer))
    return res:getFrame()
  end,
  -- pong
  [0xA] = function (res, fin, payload)
    return res:getFrame()
  end
}



--
-- This function gets a frame payload out of WebSocket
-- return nil, payload:
--    text frame,
--      with/continuation frame,
--    binary frame,
--      with/continuation frame,
--
-- Answer the frame with a 'ping' opcode by a pong, skip it, and return the next frame
-- Ignore the frame with a 'pong' opcode, skip it, and return the next frame
--
-- In case of disconnect:
--  8, { 'disconnect', reason} is returned
-- In case of a WebSocket proto error:
-- -2|-3, {error_reason, reason} is returned
-- -4, payload; if payload is not xored or if it is xored when it shouldn't
function websocket_metatable:getFrame(strict)
  local strict = strict or 1
  local client = self.client
  local framePreamble, errmsg = client:read(2)
  if framePreamble == nil then
    return -1, errmsg
  end

  local fin, opcode, payload_len, mask = core.parseFrameHeader1(framePreamble)

  local action = reactionOnOpcode[opcode]

  if action == nil then
    client:close()
    return -1, 'invalid opcode given'
  end

  local headerSecondPartLen = 0

  if mask == 1 then
    headerSecondPartLen = headerSecondPartLen + 4
  end

  if (payload_len == 126) then
    headerSecondPartLen = headerSecondPartLen + 2
  elseif (payload_len == 127) then
    headerSecondPartLen = headerSecondPartLen + 8
  end

  local payload, errmsg
  if headerSecondPartLen ~= 0 then
    local frameSecondPart, errmsg = client:read(headerSecondPartLen)

    if frameSecondPart == nil then
      return -1, "On 2nd header part " .. errmsg
    end

    local finalPayloadLen, mask_key = core.parseFrameHeader2(frameSecondPart)

    if finalPayloadLen == nil then
      finalPayloadLen = payload_len
    end

    payload, errmsg = client:read(finalPayloadLen)

    if payload == nil then
      return -1, "On payload " .. errmsg
    end

    if (mask_key) then
      payload = core.decodeFramePayload(mask_key, payload)
      local err, payload = action(self, fin, payload)
      if err then
        return err, payload
      end

      -- the message is masked
      if (self.clientOrServer == 0) then
        return nil, payload
      elseif (self.clientOrServer == 1) then
        if strict == 1 then
          self:close(closeMsg[1002])
        end
        return -4, payload
      end
    end
    
    local err, payload = action(self, fin, payload)

    if err then
      return err, payload
    end

    if (self.clientOrServer == 1) then
      return nil, payload
    elseif (self.clientOrServer == 0) then
      if strict == 1 then
        self:close(closeMsg[1002])
      end
      return -4, payload
    end
  else
    -- small payload
    payload, errmsg = client:read(payload_len)

    if payload == nil then
      return -1, "On payload " .. errmsg
    end

    local err, payload = action(self, fin, payload)

    if err then
      return err, payload
    end

    if (self.clientOrServer == 1) then
      return nil, payload
    elseif (self.clientOrServer == 0) then
      if strict == 1 then
        self:close(closeMsg[1002])
      end
      return -4, payload
    end
  end
end

function serverWebSocketHandler(req, res) -- %{
  local upgrade = (req.headers.upgrade or ''):lower()
  local connection = (req.headers.connection or ''):lower()
  local version = (req.headers['sec-websocket-version'] or ''):lower()

  if upgrade ~= 'websocket' or
     connection:find('upgrade') == nil then
    return -1, "not a websocket connection"
  end

  if version ~= '13' then
    res.status = 400
    res.headers['Sec-WebSocket-Version'] = 13
    return -1, "need websocket v13"
  end

  local secWebSocketKey = req.headers['sec-websocket-key'] or ''

  if secWebSocketKey == '' then
    return -1, "Sec-Websocket-Key is missing"
  end

  local secWebSocketAccept = base64encode(sha1(secWebSocketKey .. rfc6455GUID)) .. ''

  res.headers['Connection'] = 'Upgrade'
  res.headers['Upgrade'] = 'websocket'
  res.headers['Sec-WebSocket-Accept'] = secWebSocketAccept

  local rope = {}
  rope[1] = format('HTTP/%s 101 Switching Protocols\r\n', req.version)

  res:appendheader(rope)

  local client = req.client
  -- client:cork()
  local ok, err = client:write(concat(rope))
  -- client:uncork()

  res.client = client
  res.clientOrServer = 0
  res.detach = true

  setmetatable(res, websocket_metatable)
end -- }%

local client = require 'lem.http.client'

function clientWebSocket(to)
  local randomb64string = ('xxxxxxxxxxxx'):gsub('x', function ()
                            return string.char(string.byte('A') + (math.random(100))%25)
                          end)

  local request_detail = {
    url=to,
    method='GET',
    headers = {
      ['Sec-WebSocket-Version'] = 13,
      ['Connection']            = 'Upgrade',
      ['Upgrade']               = 'WebSocket',
      ['Sec-WebSocket-Key']     = randomb64string,
  }}

  local c = client.new()

  if type(to) == "table" then
    request_detail.url = to.url
    if to.req then
      for k, v in pairs(to.req) do
        request_detail[k] = v
      end
    end
    if to.ssl then
      c.ssl = to.ssl
    end
  end

  local res, err = c:request(request_detail)

  if res == nil then
    return nil, {-1, 'connection fail', err}
  end

  if res.status ~= 101 then
    return nil, {-2, 'unexpected status', res.status, res.text}
  end

  res.clientOrServer = 1
  res.client = res.conn
  res.conn = nil

  return setmetatable(res, websocket_metatable)
end

return { serverHandler = serverWebSocketHandler,
         client = clientWebSocket }
