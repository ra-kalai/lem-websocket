#!/usr/bin/env lem
--
-- This file is part of lem-websocket
--
-- lem-websocket is free software: you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as
-- published by the Free Software Foundation, either version 3 of
-- the License, or (at your option) any later version.
--
-- lem-websocket is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with lem-websocket.  If not, see <http://www.gnu.org/licenses/>.
--

local utils    = require 'lem.utils'
local websocketCore = require 'lem.websocket.core'

function strtohex(s)
  return (s:gsub('.', function (s)
    return string.format("%02x ",string.byte(s))
  end))
end

function hextostr(s)
  return (s:gsub(' ',''):gsub('..', function (s)
    return string.char(tonumber(s, 16))
  end))
end

function expect(v, e, msg)
  if v ~= e then
    print(msg .. ' got\n', v, 'expected\n', e)
    os.exit(1)
  end
end


function benchFun(testname, fun, count)
  local now = utils.updatenow()
  local is
  local err = false
  for i=1,count do
    if not fun() then
      err = true
      is = i
      break
    end
  end
  local rtime = utils.updatenow() - now

  if not err then
    print(string.format("%s> %d iteration in %3.8fs | 1x avg: %3.8f | %f Hz",
      testname,
      count,
      rtime,
      rtime/count,
      1/(rtime/count)
    ))
  else
    print("!!!!!", testname, 'FAIL')
    print(string.format("%s> %d iteration in %3.8fs | 1x avg: %3.8f | %f Hz",
      testname,
      is,
      rtime,
      rtime/is,
      1/(rtime/is)
    ))
  end
end

local sha1sumtest = {
	a        = "86f7e437faa5a7fce15d1ddcb9eaeaea377667b8",
	ab       = "da23614e02469a0d7c7bd1bdab5c9c474b1904dc",
	abc      = "a9993e364706816aba3e25717850c26c9cd0d89d",
	abcd     = "81fe8bfe87576c3ecb22426f8e57847382917acf",
	abcde    = "03de6c570bfe24bfc328ccd7ca46b76eadaf4334",
	abcdef   = "1f8ac10f23c5b5bc1167bda84b833e5c057a77d2",
	abcdefg  = "2fb5e13419fc89246865e7a324f476ec624e8740",
}


print('### sha1 part check')
for k, v in pairs(sha1sumtest) do
	local expected = hextostr(v)
	local val = websocketCore.sha1(k)
	expect(val, expected, "sha1 wrong for " .. k)
end
print('### sha1 part look fine')

local b64test = {
	['pleasure.'] = 'cGxlYXN1cmUu',
	['leasure.']  = 'bGVhc3VyZS4=',
	['easure.']   = 'ZWFzdXJlLg==',
	['asure.']    = 'YXN1cmUu',
	['sure.']     = 'c3VyZS4=',
	['Man is distinguished, not only by his reason, but by this singular' ..
	 ' passion from other animals, which is a lust of the mind, that by a perseverance' ..
	 ' of delight in the continued and indefatigable generation of knowledge, exceeds' ..
	 ' the short vehemence of any carnal pleasure.'] =
	 										'TWFuIGlzIGRpc3Rpbmd1aXNoZWQsIG5vdCBvbmx5IGJ5IGhpcyByZWFzb24sI' .. 
	 										'GJ1dCBieSB0aGlzIHNpbmd1bGFyIHBhc3Npb24gZnJvbSBvdGhlciBhbmltYW' ..
											'xzLCB3aGljaCBpcyBhIGx1c3Qgb2YgdGhlIG1pbmQsIHRoYXQgYnkgYSBwZXJ' .. 
											'zZXZlcmFuY2Ugb2YgZGVsaWdodCBpbiB0aGUgY29udGludWVkIGFuZCBpbmRl' ..
											'ZmF0aWdhYmxlIGdlbmVyYXRpb24gb2Yga25vd2xlZGdlLCBleGNlZWRzIHRoZ' ..
											'SBzaG9ydCB2ZWhlbWVuY2Ugb2YgYW55IGNhcm5hbCBwbGVhc3VyZS4='

}


print('### b64encode part checking')
for k, v in pairs(b64test) do
	local val = websocketCore.base64encode(k)
	expect(val, v, "b64enc wrong for " .. k)
end
print('### b64encode part look fine')


print('### checking creation speed of frame')
local basicIteration = 4000000

benchFun('creating frame not xored 32b',function() 
  local frame = websocketCore.buildframe("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 0x81, 0)
	return true
end, basicIteration)
benchFun('creating frame not xored 64b',function() 
  local frame = websocketCore.buildframe(
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 0x81, 0)
	return true
end, basicIteration)
benchFun('creating frame not xored 128b',function() 
  local frame = websocketCore.buildframe(
		[[aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa]]
		, 0x81, 0)
	return true
end, basicIteration)
benchFun('creating frame xored 32b',function() 
  local frame = websocketCore.buildframe("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 0x81, 1)
	return true
end, basicIteration)
benchFun('creating frame xored 64b',function() 
  local frame = websocketCore.buildframe(
		"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 0x81, 1)
	return true
end, basicIteration)
benchFun('creating frame xored 128b',function() 
  local frame = websocketCore.buildframe(
		[[aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa]]
		, 0x81, 1)
	return true
end, basicIteration)
--os.exit(1)


local basicFrame = {
  ["02 03 41 41 41"] = {fin=0, opcode=2, mask=0, payload_len=3, payload="AAA"},

  ["81 85 6e 53 78 f4 0c 3f 19 95 0f"] = {fin=1, opcode=1, mask=1,
                                          payload_len=5, payload_len2=nil,
                                          mask_key="6e 53 78 f4", payload="blaaa"},
  ["81 85 75 a7 6b b9 17 cb 0a d8 14"] = {fin=1, opcode=1, mask=1,
                                          payload_len=5, payload_len2=nil,
                                          mask_key="75 a7 6b b9", payload="blaaa"},
}

print('creating frame for decoding bench')

for i=1,2000,1 do
  local payload = string.rep('bla', i)
  local frame = websocketCore.buildframe(payload, 0x81, 0)
  local pload1len = nil 
  local pload2len = nil 
  local size = i*3
  if size < 126 then
    pload1len = size
  elseif size < 0xffff then
    pload1len = 126
    pload2len = size
  elseif size > 0xffff then
    pload1len = 127
    pload2len = size
  end

  basicFrame[strtohex(frame)] = { fin=1, opcode=1, mask=0, payload = payload,
                                  payload_len = pload1len, payload_len2 = pload2len }
end


for i=1,2000,1 do
  local payload = string.rep(string.rep('a',(i%13)+1), i)
  local frame = websocketCore.buildframe(payload, 0x81, 1)
  local pload1len = nil 
  local pload2len = nil 
  local size = i*((i%13)+1)
  if size < 126 then
    pload1len = size
  elseif size < 0xffff then
    pload1len = 126
    pload2len = size
  elseif size > 0xffff then
    pload1len = 127
    pload2len = size
  end

  basicFrame[strtohex(frame)] = { fin=1, opcode=1, mask=1, payload = payload,
                                  payload_len = pload1len, payload_len2 = pload2len }
end


local str = ""
print('start decoding - bench')
benchFun('checking decoding of frame', function() 
	local len_decoded = 0
	local len_decoded_xor = 0
	local frame_count = 0
	local frame_xor_count = 0

	for k, v in pairs(basicFrame) do
	  str = hextostr(k)
		len_decoded = len_decoded + #str
		frame_count = frame_count + 1

	  framepreamble = str:sub(1, 2)
	  local fin, opcode, payload_len, mask = websocketCore.parseFrameHeader1(framepreamble)
	
	  expect(fin, v.fin, "fin fail in " .. k)
	  expect(opcode, v.opcode, "opcode fail in " .. k)
	  expect(mask, v.mask, "mask fail in " .. k)
	  expect(payload_len, v.payload_len, "payload_len fail in " .. k)
	
	  local second_part_len = 2
	  if (mask == 1) then
	    second_part_len = second_part_len + 4
	  end
	
	  if (payload_len == 126) then
	    second_part_len = second_part_len + 2
	  elseif (payload_len == 127) then
	    second_part_len = second_part_len + 8
	  end
	
	  local payload_start
	
	  if (second_part_len ~= 2) then
	    framesecondpart = str:sub(3, second_part_len)
	    local payload_len2, mask_key = websocketCore.parseFrameHeader2(framesecondpart)
	    local e_mask_key = nil
	    if v.mask_key then
	      e_mask_key = hextostr(v.mask_key)
	      expect(mask_key, e_mask_key, "mask_key fail in " .. k)
	    end
	
	    payload_start = second_part_len + 1
	    payload = str:sub(payload_start)
	    if (mask_key) then
	      payload = websocketCore.decodeFramePayload(mask_key, payload)
	      expect(payload, v.payload, "payload fail in " .. k)
				len_decoded_xor = len_decoded_xor + #payload
				frame_xor_count = frame_xor_count + 1
	    else
	      expect(payload, v.payload, "payload fail in " .. k)
	    end
	  else
	    payload_start = 2
	    payload_end = 3 + payload_len
	    payload = str:sub(3, payload_end)
	    expect(payload, v.payload, "payload fail in " .. k)
	  end
	end

	print('frame_count', frame_count ,'frame_xor_count', frame_xor_count)
	print('total_len_frame_decoded', len_decoded ,'xored frame len', len_decoded_xor)

	return true
end, 3)

print('TEST / BENCH might be successful')

utils.exit(0)

-- vim: syntax=lua ts=2 sw=2 noet:
