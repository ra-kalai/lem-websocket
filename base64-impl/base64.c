/*
 * A base64 decoding implementation
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

#include <stdint.h>

#define $_likely(x)        __builtin_expect(!!(x), 1)
#define $_wprefetch(x)     __builtin_prefetch(x, 1, 3)

static uint8_t b64table[] = { 
  'A', 'B', 'C', 'D', 'E', 'F', 'G',
  'H', 'I', 'J', 'K', 'L', 'M', 'N',
  'O', 'P', 'Q', 'R', 'S', 'T', 'U',
  'V', 'W', 'X', 'Y', 'Z', 'a', 'b',
  'c', 'd', 'e', 'f', 'g', 'h', 'i',
  'j', 'k', 'l', 'm', 'n', 'o', 'p',
  'q', 'r', 's', 't', 'u', 'v', 'w',
  'x', 'y', 'z', '0', '1', '2', '3',
  '4', '5', '6', '7', '8', '9', '+',
  '/',
};

static int
b64_out_buffer_size(int in_buffer_size) {
  int padding = 3 - in_buffer_size % 3;
  if (padding == 3 ) padding = 0;
  return ((in_buffer_size + (padding)) / 3 * 4); 
}

static void
b64_enc(const uint8_t *b, int len, uint8_t *out) {
  int padding_count = 3 - len % 3;
  int i, b64i, e;

  for (i=0,b64i=0,e=len-2;$_likely(i<e);i+=3,b64i += 4) {
    out[b64i]   = b64table[b[i] >> 2];
    out[b64i+1] = b64table[((b[i] << 4)&0x30) | (b[i+1] >> 4)];
    out[b64i+2] = b64table[((b[i+1] << 2)&0x3c) | ((b[i+2]>>6)&0x03)];
    out[b64i+3] = b64table[b[i+2]&0x3f];
  }

  $_wprefetch(&out[b64i]);

  switch (padding_count) {
    case 1:
      out[b64i++] = b64table[b[i] >> 2];
      out[b64i++] = b64table[((b[i] << 4)&0x30)|(b[i+1] >> 4)];
      out[b64i++] = b64table[(b[i+1] << 2)&0x3c];
      out[b64i++] = '=';
      break;
    case 2:
      out[b64i++] = b64table[b[i] >> 2];
      out[b64i++] = b64table[(b[i] << 4)&0x30];
      out[b64i++] = '=';
      out[b64i++] = '=';
      break;
    default:
      break;
  }
}


#if 0
int main(int argc, char **argv) {
  char lbuf[8192];
  int ret;
  char block[8192];
  while((ret = fread(lbuf, 1, 4096, stdin)) != 0) {
  b64_enc(lbuf, ret, block);
  //printf("%d => %s\n",ret, b64_enc_block(lbuf, ret));
  }
}
#endif
