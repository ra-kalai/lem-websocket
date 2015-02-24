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

static uint8_t b64dec_table[256] = {
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,
  62,
  0,0,0,
  63,
  52, 53, 54, 55, 56, 57, 58, 59, 60, 61,
  0,0,0,0,0,0,0,
  0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
  16,17,18,19,20,21,22,23,24,25,0,
  0,0,0,0,0,
  26,27,28,29,30,31,32,33,34,35,36,37,38,39,
  40,41,42,43,44,45,46,47,48,49,50,51
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

static int
b64_dec_out_buffer_size(const uint8_t *b, int len) {
  int real_len = len;

  int padding = 0;

  if (len >= 2) {
    if (b[len-1] == '=') {
      padding += 1;
    }
    if (b[len-2] == '=') {
      padding += 1;
    }
  }

  int missing_padding = len % 4;
  real_len += missing_padding;

  return real_len / 4 * 3 -padding;
}


static void
b64_dec(const uint8_t *b, int len, uint8_t *out) {
  static int i, i2, e;
  static uint8_t v[4];


  for (i=0, i2=0, e=len-3;
       $_likely(i<e); i+=4, i2 += 3) {

    v[0] = b64dec_table[b[i]];
    v[1] = b64dec_table[b[i+1]];
    v[2] = b64dec_table[b[i+2]];
    v[3] = b64dec_table[b[i+3]];
    out[i2] =    v[0]        << 2 | (v[1] & 0x30) >> 4;
    out[i2+1] = (v[1] & 0xf) << 4 | (v[2] & 0x3c) >> 2;
    out[i2+2] = (v[2] & 0x3) << 6 |  v[3];

    //printf("i:%d (%d) %d => %c%c%c%c %02x %02x %02x\n",
    //  i, e, len,
    //  b[0], b[i+1], b[i+2], b[i+3],
    //  out[i2], out[i2+1], out[i2+2]
    //);
  }

  /* handling of non padded base64 input */
  switch (len%4) {
    case 0:
      return ;
    case 1:
      v[0] = b64dec_table[b[i]];
      v[1] = 0;
      v[2] = 0;
      v[3] = 0;
      break;
    case 2:
      v[0] = b64dec_table[b[i]];
      v[1] = b64dec_table[b[i+1]];
      v[2] = 0;
      v[3] = 0;
      break;
    case 3:
      v[0] = b64dec_table[b[i]];
      v[1] = b64dec_table[b[i+1]];
      v[2] = b64dec_table[b[i+2]];
      v[3] = 0;
      break;
  }

  out[i2] =    v[0]        << 2 | (v[1] & 0x30) >> 4;
  out[i2+1] = (v[1] & 0xf) << 4 | (v[2] & 0x3c) >> 2;
  out[i2+2] = (v[2] & 0x3) << 6 |  v[3];
}


#if 0
#include <stdio.h>
int main(int argc, char **argv) {
  char lbuf[8192];
  int ret;
  char block[8192] = {};
  char block2[8192] = {};
  printf("%d\n", b64_dec_out_buffer_size("aaaaaaa", 7));
  printf("%d\n", b64_dec_out_buffer_size("aaaa=", 5));
  printf("%d\n", b64_dec_out_buffer_size("aaaaa", 5));
  printf("%d\n", b64_dec_out_buffer_size("aaaa", 4));
  printf("%d\n", b64_dec_out_buffer_size("aaaa", 3));
  printf("%d\n", b64_dec_out_buffer_size("aaaa", 2));
  printf("%d\n", b64_dec_out_buffer_size("aaaa", 1));

  while((ret = fread(lbuf, 1, 4096, stdin)) != 0) {
  b64_enc(lbuf, ret, block);
  int size = b64_out_buffer_size(ret);
  b64_dec(block, size, block2);
  b64_dec(block, 7, block2);
  puts(block2);
  //printf("%d => %s\n",ret, b64_enc_block(lbuf, ret));

  }
}
#endif
