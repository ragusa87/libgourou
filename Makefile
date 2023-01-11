LIBDIR ?= /usr/lib
INCDIR ?= /usr/include

AR ?= $(CROSS)ar
CXX ?= $(CROSS)g++

ifeq ($(PREFIX),)
    PREFIX := /usr/local
endif

UPDFPARSERLIB = ./lib/updfparser/libupdfparser.a

CXXFLAGS += -Wall -fPIC -I./include -I./usr/include/pugixml -I./lib/updfparser/include
LDFLAGS = $(UPDFPARSERLIB) -lpugixml

VERSION     := $(shell cat include/libgourou.h |grep LIBGOUROU_VERSION|cut -d '"' -f2)

BUILD_STATIC ?= 0
BUILD_SHARED ?= 1
BUILD_UTILS  ?= 1

TARGETS =
TARGET_LIBRARIES =
ifneq ($(BUILD_STATIC), 0)
  TARGETS += libgourou.a
  TARGET_LIBRARIES += libgourou.a
endif
ifneq ($(BUILD_SHARED), 0)
  TARGETS += libgourou.so
  TARGET_LIBRARIES += libgourou.so libgourou.so.$(VERSION)
endif
ifneq ($(BUILD_UTILS), 0)
  TARGETS += build_utils
endif


ifneq ($(DEBUG),)
CXXFLAGS += -ggdb -O0 -DDEBUG
else
CXXFLAGS += -O2
endif

ifneq ($(STATIC_NONCE),)
CXXFLAGS += -DSTATIC_NONCE=1
endif

SRCDIR      := src
BUILDDIR    := obj
SRCEXT      := cpp
OBJEXT      := o

SOURCES      = src/libgourou.cpp src/user.cpp src/device.cpp src/fulfillment_item.cpp src/loan_token.cpp src/bytearray.cpp
OBJECTS     := $(patsubst $(SRCDIR)/%,$(BUILDDIR)/%,$(SOURCES:.$(SRCEXT)=.$(OBJEXT)))

all: version lib obj $(TARGETS)

version:
	@echo "Building libgourou $(VERSION)"

lib:
	mkdir lib
	./scripts/setup.sh

update_lib:
	./scripts/update_lib.sh

obj:
	mkdir obj

$(BUILDDIR)/%.$(OBJEXT): $(SRCDIR)/%.$(SRCEXT)
	$(CXX) $(CXXFLAGS) -c $^ -o $@

libgourou: libgourou.a libgourou.so

libgourou.a: $(OBJECTS) $(UPDFPARSERLIB)
	$(AR) crs $@ obj/*.o  $(UPDFPARSERLIB)

libgourou.so.$(VERSION): $(OBJECTS) $(UPDFPARSERLIB)
	$(CXX) obj/*.o -Wl,-soname,$@ $(LDFLAGS) -o $@ -shared

libgourou.so: libgourou.so.$(VERSION)
	ln -f -s $^ $@

build_utils: $(TARGET_LIBRARIES)
	make -C utils ROOT=$(PWD) CXX=$(CXX) AR=$(AR) DEBUG=$(DEBUG) STATIC_UTILS=$(STATIC_UTILS) DEST_DIR=$(DEST_DIR) PREFIX=$(PREFIX)

install: $(TARGET_LIBRARIES)
	install -d $(DESTDIR)$(PREFIX)$(LIBDIR)
# Use cp to preserver symlinks
	cp --no-dereference $(TARGET_LIBRARIES) $(DESTDIR)$(PREFIX)$(LIBDIR)
	make -C utils ROOT=$(PWD) CXX=$(CXX) AR=$(AR) DEBUG=$(DEBUG) STATIC_UTILS=$(STATIC_UTILS) DEST_DIR=$(DEST_DIR) PREFIX=$(PREFIX) install

uninstall:
	cd $(DESTDIR)$(PREFIX)/$(LIBDIR)
	rm -f $(TARGET_LIBRARIES) libgourou.so.$(VERSION)
	cd -

install_headers:
	install -d $(DESTDIR)$(PREFIX)/$(INCDIR)/libgourou
	cp --no-dereference include/*.h $(DESTDIR)$(PREFIX)/$(INCDIR)/libgourou

uninstall_headers:
	rm -rf $(DESTDIR)$(PREFIX)/$(INCDIR)/libgourou

clean:
	rm -rf libgourou.a libgourou.so libgourou.so.$(VERSION)* obj
	make -C utils clean

ultraclean: clean
	rm -rf lib
	make -C utils ultraclean
