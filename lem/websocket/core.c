/*
* This file is part of lem-websocket.
* Copyright 2015 Ralph Augé
*
* lem-websocket is free software: you can redistribute it and/or
* modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of
* the License, or (at your option) any later version.
*
* lem-websocket is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with lem-websocket. If not, see <http://www.gnu.org/licenses/>.
*/

#include <lem.h>
#include <stdint.h>

// include a sha1 implementation
#include "../../sha1-impl/sha1.c"
// include a base64 implementation
#include "../../base64-impl/base64.c"

#include <alloca.h>

static int
lem_base64encode(lua_State *T) {
  size_t buf_len;
  const char *buf = lua_tolstring(T, -1, &buf_len);

  int b64string_len = b64_out_buffer_size((int)buf_len);
  unsigned char *b64string = alloca(b64string_len);

  b64_enc((unsigned const char *)buf, buf_len, b64string);

  lua_pushlstring(T, (const char*)b64string, b64string_len);

  return 1;
}


static int
lem_sha1(lua_State *T) {
  static unsigned char hashout[20];
  static blk_SHA_CTX sha1ctx;
  size_t buf_len;
  const char *buf = lua_tolstring(T, -1, &buf_len);

  blk_SHA1_Init(&sha1ctx);
  blk_SHA1_Update(&sha1ctx, buf, buf_len);
  blk_SHA1_Final(hashout, &sha1ctx);

  lua_pop(T, 1);
  lua_pushlstring(T, (const char*)hashout, sizeof hashout);

  return 1;
}

/*
    0                   1                   2                   3
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-------+-+-------------+-------------------------------+
     |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
     |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
     |N|V|V|V|       |S|             |   (if payload len==126/127)   |
     | |1|2|3|       |K|             |                               |
     +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
     |     Extended payload length continued, if payload len == 127  |
     + - - - - - - - - - - - - - - - +-------------------------------+
     |                               |Masking-key, if MASK set to 1  |
     +-------------------------------+-------------------------------+
     | Masking-key (continued)       |          Payload Data         |
     +-------------------------------- - - - - - - - - - - - - - - - +
     :                     Payload Data continued ...                :
     + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
     |                     Payload Data continued ...                |
     +---------------------------------------------------------------+

*/

static int
lem_websocket_decode_frame_payload(lua_State *T) {
  size_t payload_key_len = 0;
  size_t payload_buf_len = 0;
  const uint8_t *xor_key_buf  = (const uint8_t*)lua_tolstring(T, 1, &payload_key_len);
  uint8_t *payload_buf  = (uint8_t*)lua_tolstring(T, 2, &payload_buf_len);

  if ((payload_key_len != 4) ||
      (payload_buf_len == 0)) {
    lua_pushnil(T);
    return 1;
  }

  int i;
#if defined(__i386__) //|| defined(__x86_64__)
    uint64_t xorkey = (uint32_t)xor_key_buf[0]
                    | (uint32_t)xor_key_buf[1] << 8
                    | (uint32_t)xor_key_buf[2] << 16
                    | (uint32_t)xor_key_buf[3] << 24;
    int e;
    for(i=0,e=payload_buf_len-4;i<=e;i+=4) {
      (*(uint32_t*)(&payload_buf[i])) ^=  xorkey;
    }
#elif defined(__x86_64__)
    uint64_t xorkey64 = (uint64_t)xor_key_buf[0]
                      | (uint64_t)xor_key_buf[1] << 8
                      | (uint64_t)xor_key_buf[2] << 16
                      | (uint64_t)xor_key_buf[3] << 24
                      | (uint64_t)xor_key_buf[0] << 32
                      | (uint64_t)xor_key_buf[1] << 40
                      | (uint64_t)xor_key_buf[2] << 48
                      | (uint64_t)xor_key_buf[3] << 56;
    int e;
    for(i=0,e=payload_buf_len-8;i<=e;i+=8) {
      (*(uint64_t*)(&payload_buf[i])) ^= xorkey64;
    }
#else
    i = 0;
#endif
  for(;i<payload_buf_len;i++) {
    payload_buf[i] ^= xor_key_buf[i%4];
  }

  lua_pushlstring(T, (const char *)payload_buf, payload_buf_len);
  return 1;
}

static int
lem_websocket_parse_frame_header2(lua_State *T) {
  size_t buf_len;
  const uint8_t *buf  = (const uint8_t*)lua_tolstring(T, -1, &buf_len);

  int size = 0;
  char *key = NULL;

  switch (buf_len) {
    case 2:
      size  = buf[0] | ((int)(buf[1] << 8));
      break;
    case 4:
      key = alloca(4);
      memmove(key, buf, 4);
      break;
    case 6:
      size  = buf[0] | ((int)(buf[1] << 8));
      key = alloca(4);
      memmove(key, buf+2, 4);
      break;
    case 8:
      size  =  buf[0] |
             ((uint32_t)(buf[1]        << 8)) |
             ((uint32_t)(buf[2]        << 16)) |
             ((uint32_t)((buf[3]&0x7f) << 24)) ;
      break;
    case 12:
      size  =  buf[0] |
             ((uint32_t)(buf[1]        << 8)) |
             ((uint32_t)(buf[2]        << 16)) |
             ((uint32_t)((buf[3]&0x7f) << 24)) ;

      key = alloca(4);
      memmove(key, buf+8, 4);
      break;
  }

  if ((size == 0) &&
      (key == NULL)) {
    lua_pushnil(T);
    lua_pushnil(T);
    return 2;
  }

  if (size == 0) {
    lua_pushnil(T);
  } else {
    lua_pushinteger(T, size);
  }
  if (key == NULL) {
    lua_pushnil(T);
  } else {
    lua_pushlstring(T, key, 4);
  }

  return 2;
}

static int
lem_websocket_parse_frame_header1(lua_State *T) {
  size_t buf_len;
  const uint8_t *buf  = (const uint8_t*)lua_tolstring(T, -1, &buf_len);

  if (buf_len != 2) {
    lua_pushnil(T);
    lua_pushnil(T);
    lua_pushnil(T);
    lua_pushnil(T);

    return 4;
  }
  int fin         = (buf[0] & 0x80) != 0;
  int opcode      = (buf[0] & 0x0f);
  int mask        = (buf[1] & 0x80) != 0;
  int payload_len = (buf[1] & 0x7f);

  lua_pushinteger(T, fin);
  lua_pushinteger(T, opcode);
  lua_pushinteger(T, payload_len);
  lua_pushinteger(T, mask);
  
  return 4;
}

static int
lem_websocket_buildframe(lua_State *T) {
  int args = lua_gettop(T);

  size_t buf_len;
  const char *buf;
  int opcode = 0x81;

  int mask = 0;
  if (args == 3) {
    buf  = lua_tolstring(T, -3, &buf_len);
    opcode = lua_tointeger(T, -2);
    mask = lua_tointeger(T, -1) ? 1 : 0;
  } else {
    lua_pushinteger(T, -1);
    lua_pushstring(T, "expected buildrame(payload, opcode=0x81|129, mask=0)");
    return 2;
  }

  int frame_size = 2;
  int payload_len = 0;

  if (mask) {
    frame_size += 4;
  }
  
  if (buf_len <= 125) {
    payload_len = buf_len;
  } else if ( buf_len < 0xffff) {
    frame_size += 2;
    payload_len = 126;
  } else {
    frame_size += 8;
    payload_len = 127;
  }

  frame_size += buf_len;
  uint8_t *frame = alloca(frame_size);

  frame[0] = (uint8_t)opcode;
  frame[1] = mask << 7;
  frame[1] |= payload_len;

  int findex = 2;

  if (payload_len == 126) {
    frame[findex++] = (buf_len >>  8) & 0xff;
    frame[findex++] =  buf_len        & 0xff;
  } else if (payload_len == 127){
    frame[findex++] = (buf_len >> 24) & 0xff;
    frame[findex++] = (buf_len >> 16) & 0xff;
    frame[findex++] =  buf_len        & 0xff;
    frame[findex++] = 0;
    frame[findex++] = 0;
    frame[findex++] = 0;
  }

  if (mask) {
    static uint32_t xorkey = 0xf1c37166;
    xorkey ^= 0xf24d6ade;
    xorkey *= 31;

    uint8_t *xorkey_buf = &frame[findex];

    memmove(xorkey_buf, &xorkey, 4);
    findex += 4;

    int i;

#if defined(__i386__)
    int e;
    for(i=0,e=buf_len-4;i<=e;i+=4) {
      (*((uint32_t*)(&frame[i+findex]))) = (*((uint32_t*)(&buf[i]))) ^ xorkey;
    }
#elif defined(__x86_64__)
    uint64_t xorkey64 = (uint64_t)xorkey_buf[0]
                      | (uint64_t)xorkey_buf[1] << 8
                      | (uint64_t)xorkey_buf[2] << 16
                      | (uint64_t)xorkey_buf[3] << 24
                      | (uint64_t)xorkey_buf[0] << 32
                      | (uint64_t)xorkey_buf[1] << 40
                      | (uint64_t)xorkey_buf[2] << 48
                      | (uint64_t)xorkey_buf[3] << 56;
    int e;
    for(i=0,e=buf_len-8;i<=e;i+=8) {
      (*(uint64_t*)(&frame[i+findex])) = (*((uint64_t*)(&buf[i]))) ^ xorkey64;
    }
#else
    i = 0;
#endif
    for(;i<buf_len;i+=1) {
      frame[i+findex] = buf[i] ^ xorkey_buf[i%4];
    }
  } else {
    memmove(frame + findex, buf, buf_len);
  }
  
  lua_pushlstring(T, (const char*)frame, frame_size);

  return 1;
}

static const luaL_Reg lem_websocket_core_export[] = {
  {"base64encode",        lem_base64encode},
  {"sha1",                lem_sha1},
  {"parseFrameHeader1",   lem_websocket_parse_frame_header1},
  {"parseFrameHeader2",   lem_websocket_parse_frame_header2},
  {"decodeFramePayload",  lem_websocket_decode_frame_payload},
  {"buildframe",          lem_websocket_buildframe},
  {NULL, NULL },
};

static void
h_set_methods(lua_State *L, const luaL_Reg *func_list) {
  for(;*func_list->func!=NULL;func_list++) {
    lua_pushcfunction(L, func_list->func);
    lua_setfield(L, -2, func_list->name);
  }
}

int
luaopen_lem_websocket_core(lua_State *L) {
  lua_newtable(L);
  h_set_methods(L, lem_websocket_core_export);

  return 1;
}
