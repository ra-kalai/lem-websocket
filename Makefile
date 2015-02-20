include config.mk


clib := lem/websocket/core.so

all: $(clib)

.PHONY: test strip

$(clib): lem/websocket/core.c \
         base64-impl/base64.c \
         sha1-impl/sha1.c
	$(CC) $(CFLAGS) $(LDFLAGS) \
	lem/websocket/core.c \
	 -o $@ 

strip: $(clib)
	strip -s $(clib)

install: $(clib) strip
	mkdir -p $(cmoddir)/lem/websocket
	mkdir -p $(lmoddir)/lem/websocket
	install -m 644 lem/websocket/core.so     $(cmoddir)/lem/websocket/
	install -m 644 lem/websocket/handler.lua $(lmoddir)/lem/websocket/

test:
	lem test/bench.lua

clean:
	rm -f lem/websocket/core.so
