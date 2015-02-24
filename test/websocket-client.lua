#!/usr/bin/env lem
--
-- This file is part of lem-websocket
-- Copyright 2015 Ralph Augé
--
-- LEM is free software: you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as
-- published by the Free Software Foundation, either version 3 of
-- the License, or (at your option) any later version.
--
-- LEM is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with lem-websocket.  If not, see <http://www.gnu.org/licenses/>.
--

local utils  = require 'lem.utils'
local websocket = require 'lem.websocket.handler'

local url = arg[1] or 'http://localhost:8080/ws'

local running = 0
utils.spawn(function ()
	local err, res = websocket.client(url)
	if not err then
		res:sendText('["join"]')
		utils.spawn(function () 
			local err, payload
			while err == nil do
				err, payload = res:getFrame()
				print(err, payload)
			end
			running = 1
		end)
	else
		print('error on connect', err, res)
		running = 1
	end
end)


local sleeper = utils.newsleeper()
repeat
	sleeper:sleep(0.001)
until running == 0

-- vim: set ts=2 sw=2 noet:
