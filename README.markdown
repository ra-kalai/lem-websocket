lem-websocket
================


About
-----

lem-websocket is a library for the [Lua Event Machine][lem].
This library goal is to help handling WebSocket connection within LEM.

[lem]: https://github.com/esmil/lem


Installation
------------

Get the source and do

    make

    # run test / benchmark / regression
    make test
   
    # install
    make install

Usage
-----

Import the module using something like

    local websocket = require 'lem.websocket.handler'

This sets `websocket` to a table with two function:

* __client(url)__
  
  ...

* __serverHandler(req, res)__
  
  This function would normally be called inside a hathaway hook.   
  If the handshake failed, this function return a negative number, followed by an error.   

  Otherwise; if the handshake has succeed, this function will not be returning anything
  **and** the **res object** metatable will have been updated, to contains the following methods:

* __res:close(msg={1000}"normal closure")__

  Close the WebSocket connection, a msg string will be sent to the client before the socket is shutdown.   
  If msg is nil a default msg: reason 1000 - normal closure will be sent 

* __res:sendText(payload)__

  Send a text frame over the websocket; 
  same return values as io:write()

* __res:sendBinary(payload)__

  Send a binary frame over the websocket; 
  same return values as io:write()


* __res:getFrame(strict=1)__   
  Get a frame payload out the WebSocket connection   
  return nil, payload:   
     after receivig is a text frame   
     after receivig is a binary frame   

  Answer the frame with a 'ping' opcode by a pong, skip it, and return the next frame   
  Ignore the frame with a 'pong' opcode, skip it, and return the next frame   

  In case of disconnect:   
   8, { 'disconnect', reason} is returned   

  In case of a WebSocket proto error:  
  -2|-3, {error_reason, reason} is returned   
  -4, payload; if payload is not xored or if it is xored when it shouldn't   
  if strict mode parameter is on (strict=1) the WebSocket connection is also closed   


Performance / Regression test
-------
  
    Intel(R) Core(TM) i5-3470S CPU @ 2.90GHz
    Linux 3.18.6-1-ARCH #1 SMP PREEMPT Sat Feb 7 08:44:05 CET 2015 x86_64 GNU/Linux
    lua 5.2

    make test

    ### sha1 part check
    ### sha1 part look fine
    ### b64encode part checking
    ### b64encode part look fine
    ### checking creation speed of frame
    creating frame not xored 32b> 4000000 iteration in 0.62228107s | 1x avg: 0.00000016 | 6427963.445715 Hz
    creating frame not xored 64b> 4000000 iteration in 0.73989439s | 1x avg: 0.00000018 | 5406176.953749 Hz
    creating frame not xored 128b> 4000000 iteration in 0.91366839s | 1x avg: 0.00000023 | 4377955.969452 Hz
    creating frame xored 32b> 4000000 iteration in 1.13421106s | 1x avg: 0.00000028 | 3526680.464624 Hz
    creating frame xored 64b> 4000000 iteration in 0.81981325s | 1x avg: 0.00000020 | 4879159.970522 Hz
    creating frame xored 128b> 4000000 iteration in 0.97001314s | 1x avg: 0.00000024 | 4123655.472615 Hz
    creating frame for decoding bench
    start decoding - bench
    frame_count	4003	frame_xor_count	2002
    total_len_frame_decoded	20049907	xored frame len	14023032
    frame_count	4003	frame_xor_count	2002
    total_len_frame_decoded	20049907	xored frame len	14023032
    frame_count	4003	frame_xor_count	2002
    total_len_frame_decoded	20049907	xored frame len	14023032
    checking decoding of frame> 3 iteration in 21.99033713s | 1x avg: 7.33011238 | 0.136424 Hz
    TEST / BENCH might be successful
    

License
-------

lem-websocket is free software. It is distributed both under the terms of the [GNU General Public License][gpl] any revision, and the [GNU Lesser General Public License][lgpl] any revision.   

The SHA1 implementation is taken from [Git][git] and is also covered by the [GNU General Public License][gpl]

[git]: https://github.com/git/git
[gpl]: http://www.fsf.org/licensing/licenses/gpl.html
[lgpl]: http://www.fsf.org/licensing/licenses/lgpl.html

Contact
-------

Please send bug reports, patches and feature requests to me <ra@apathie.net>.
