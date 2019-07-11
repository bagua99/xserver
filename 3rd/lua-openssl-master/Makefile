T=openssl

PREFIX		?=/usr/local
LIB_OPTION	?= -shared 

#Lua auto detect
LUAV		?= $(shell lua -e "_,_,v=string.find(_VERSION,'Lua (.+)');print(v)")
LUA_CFLAGS	?= -I$(PREFIX)/include/lua$(LUAV)
LUA_LIBS	?= -L$(PREFIX)/lib 
LUA_LIBDIR	?= $(PREFIX)/lib/lua/$(LUAV)

#OS auto detect
SYS := $(shell gcc -dumpmachine)

# Do linux things
LDFLAGS		    = -fPIC -lrt -ldl -llua -lm
OPENSSL_LIBS	?= $(shell pkg-config openssl --libs) 
OPENSSL_CFLAGS	?= --shared
CFLAGS		 = -fPIC $(OPENSSL_CFLAGS) $(LUA_CFLAGS) 
LIB_OPTION	 = -Wl,--no-undefined

LIBNAME= $T.so.$V

# Compilation directives
WARN_MOST	= -Wall -W -Waggregate-return -Wcast-align -Wmissing-prototypes -Wnested-externs -Wshadow -Wwrite-strings -pedantic
WARN		= -Wall -Wno-unused-value
WARN_MIN	= 
CFLAGS		+= $(WARN_MIN) -DPTHREADS 
CC= gcc -g -Wall $(CFLAGS) -Ideps


OBJS=src/asn1.o src/auxiliar.o src/bio.o src/cipher.o src/cms.o src/compat.o src/crl.o src/csr.o src/dh.o src/digest.o src/dsa.o \
src/ec.o src/engine.o src/hmac.o src/lbn.o src/lhash.o src/misc.o src/ocsp.o src/openssl.o src/ots.o src/pkcs12.o src/pkcs7.o    \
src/pkey.o src/rsa.o src/ssl.o src/th-lock.o src/util.o src/x509.o src/xattrs.o src/xexts.o src/xname.o src/xstore.o src/xalgor.o src/callback.o 

.c.o:
	$(CC) -c -o $@ $?

all: $T.so
	echo $(SYS)

$T.so: $(OBJS)
	$(CC) $(CFLAGS) $(LIB_OPTION) -o $T.so $(OBJS) $(OPENSSL_LIBS) $(LUA_LIBS) $(LDFLAGS)

install: all
	mkdir -p $(LUA_LIBDIR)
	cp $T.so $(LUA_LIBDIR)

clean:
	rm -f $T.so $(OBJS) 
