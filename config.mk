CC := gcc

PKG_CONFIG_PATH := /usr/local/lib/pkgconfig/
PKG_CONFIG := pkg-config
cmoddir = $(shell \
            PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) $(PKG_CONFIG) --variable=INSTALL_CMOD lem)
lmoddir = $(shell \
            PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) $(PKG_CONFIG) --variable=INSTALL_LMOD lem)

CFLAGS := -Wall -Wno-strict-aliasing -fPIC -nostartfiles -shared \
       $(shell \
         PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) \
         $(PKG_CONFIG) --cflags lem) 
#					-g \

LDFLAGS := -Os
