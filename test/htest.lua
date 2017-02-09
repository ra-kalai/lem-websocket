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
local io       = require 'lem.io'
local hathaway = require 'lem.hathaway'
local websocketHandler = require 'lem.websocket.handler'
local format = string.format

utils.poolconfig(100, 10, 20)

hathaway.debug = print -- must be set before import()
hathaway.import()      -- when using single instance API


local listeningPort = arg[1] or '8080'

GET('/', function(req, res)
	local accept = req.headers['accept']

	res.headers['Content-Type'] = 'text/html'
	res:add([[
<html id=root>
<head>
	<title>Hathaway HTTP websocket</title>
	<style type="text/css">
	th { text-align:left; }
		#root {
			position: relative;
			width: 100%%;
			height: 100%%;
		}
		.cursor {
			position: absolute;
			width: 14px;
			height: 14px;
			background: #333;
			margin-left: -7px;
			margin-top: -7px;
			z-index: 2000;
		}
	</style>
</head>
<body>

<h2>Request</h2>
<table>
	<tr><th>Method:</th><td>%s</td></tr>
	<tr><th>Uri:</th><td>%s</td></tr>
	<tr><th>Version:</th><td>%s</td></tr>
</table>

<h2>Headers</h2>
<table>
]], req.method or '', req.uri or '', req.version)

	for k, v in pairs(req.headers) do
		res:add('  <tr><th>%s</th><td>%s</td></tr>\n', k, v)
	end

	res:add([=[
</table>

<h2>Body</h2>
<script>
	var root = document.getElementById('root');

	var cursorMap = {};

	function createUpdateCursor(cursorid, pos) {
		var cursor = cursorMap[cursorid];

		if (typeof cursor === 'undefined') {
			cursor = document.createElement("div"); 
			cursor.setAttribute('class', 'cursor');
			cursorMap[cursorid] = cursor;
			root.appendChild(cursor);
		}
		cursor.setAttribute('style', 'left:' + pos[0] + 'px;' +
																	'top:'  + pos[1] + 'px;');
	}

	var mouse = {x: 0, y: 0};

	document.addEventListener('mousemove', function(e){ 
		mouse.x = e.clientX || e.pageX; 
		mouse.y = e.clientY || e.pageY 
	}, false);

	var socket = new WebSocket(document.location.origin
		.replace(/^http/,'ws')+"/ws");
	socket.onmessage = function (msg) {
		var msg = JSON.parse(msg.data);
		if ((msg[0] !== 'start') && (msg[0] !== 'left')) {
			createUpdateCursor(msg[0], JSON.parse(msg[1]));		
		} else if (msg[0] === 'left') {
			var elem;
			if (elem = cursorMap[msg[1]]) {
				elem.remove();
				delete cursorMap[msg[1]];
			}
		}
	};
	socket.onopen = function () {
		socket.send('["join"]');
		var oldx = mouse.x, oldy = mouse.y;
		setInterval(function () {
			if ((oldx !== mouse.x)||(oldy != mouse.y)) {
				oldx = mouse.x; oldy = mouse.y;
				socket.send('['+oldx+','+oldy+']');
			}
		}, 20);
	};
</script>
</body>
</html>
]=])
end)

local nConn = 0
local clientMap = {}

function brodcastMsg(msg)
	for res, active in pairs(clientMap) do
		if active then
			local err, bla = res:sendText(msg)
			print('res:sendText', err, bla)
		end
	end
end

function tid(t)
	return tostring(t):gsub('table: ', '')
end

GET('/ws-test', function(req, res)
	local err, errMsg = websocketHandler.serverHandler(req, res)

	if (err ~= nil) then
		res.status = 400
		res.headers['Content-Type'] = 'text/plain'
		res:add('Websocket Failure!\n' .. errMsg .. "\n")
		return
	end

	local err, payload = res:getFrame()
	res:sendText(payload)
	res:sendText("bye\n")
	res:close();
end)


local clientsList = {}

GET('/ws-test2', function(req, res)
	local err, errMsg = websocketHandler.serverHandler(req, res)

	if (err ~= nil) then
		res.status = 400
		res.headers['Content-Type'] = 'text/plain'
		res:add('Websocket Failure!\n' .. err .. "\n")
		return
	end
	clientsList[res] = true

	dont_exit = true

	local payload

	while dont_exit do
		err, payload = res:getFrame()
		if err ~= nil then
			clientsList[res] = nil
			dont_exit = false
		end
		for client, ok in pairs(clientsList) do
			if ok then
				client:sendText(payload)
			end
		end
	end
  res:sendText("bye\n")
  --res:close();
end)

GET('/ws', function(req, res)
	local err, errMsg = websocketHandler.serverHandler(req, res)

	if (err ~= nil) then
		res.status = 400
		res.headers['Content-Type'] = 'text/plain'
		res:add('Websocket Failure!\n' .. err .. "\n")
		return 
	end

	local err, payload

	clientMap[res] = true
	nConn = nConn + 1
	while true do
		err, payload = res:getFrame()
		print('res:getFrame', err, payload)
		if err then
			aalive = false 
			clientMap[res] = nil
			nConn = nConn - 1
			brodcastMsg(format('["left", "%s"]', tid(res)))
			break
		end

		if (payload == '["join"]') then
			res:sendText(format('["start", %q, %d]', tid(res), nConn))
			for k, v in pairs(clientMap) do
				if (v and v ~= true) then
					res:sendText(format('[%q, %q]', tid(k), v))
				end
			end
		else
			clientMap[res] = payload
			brodcastMsg(format('["%s", %q]',tid(res), payload))
		end

	end
	res:close()
end)

print('listening on ' .. listeningPort)
Hathaway('*', listeningPort)

-- vim: syntax=lua ts=2 sw=2 noet:
