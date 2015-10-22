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

local msgsizestart = arg[1] or 100
local msgsizemax = arg[2] or 101
local url = arg[3] or 'http://localhost:8080/ws-test'

local keep_running

utils.poolconfig(100, 10, 20)
for msgsize = msgsizestart, msgsizemax do 

	utils.spawn(function ()
		local err, res = websocket.client(url)
		local msg = string.rep("a", msgsize)
	
		if not err then
			res:sendText(msg)
			err, payload = res:getFrame()
	
			if payload == msg then
				err, payload = res:getFrame()
				if (payload == 'bye\n') then
					print('ok', msgsize)
				else
					print('nok', msgsize)
				end
				keep_running = 0
			end
			res:close()
		else
			print('error on connect', err, res)
			keep_running = 0
		end
	end)

	keep_running = 1
end

local sleeper = utils.newsleeper()
repeat
	sleeper:sleep(0.001)
until keep_running == 1

-- vim: set ts=2 sw=2 noet:
