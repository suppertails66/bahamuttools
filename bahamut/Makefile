IDIR := src
SRCDIR := src
ODIR := obj
LDIR :=

BLACKTDIR = ../blackt
LIBMDDIR = ../libmd

AR=ar
CXX=g++
# Compile only
CDEFINES = -DBLACKT_ENABLE_LIBPNG
#CLIBS = -lpng
CFLAGS = -std=gnu++11 -O2 -Wall -L${LIBMDDIR} -lmd -L${BLACKTDIR} -lblackt -lpng
CINCLUDES = -I${BLACKTDIR}/src -I${LIBMDDIR}/src
CXXFLAGS=$(CFLAGS) $(CDEFINES) $(CINCLUDES) -I$(IDIR)

LIBDEPS := $(LIBMDDIR)/libmd.a $(BLACKTDIR)/libblackt.a

TOOLSRCS := $(wildcard $(SRCDIR)/*.cpp)
TOOLSINDIR := $(patsubst %.cpp,%,$(TOOLSRCS))
TOOLS := $(notdir $(TOOLSINDIR))

.SECONDEXPANSION:

all: $(BLACKTDIR)/libblackt.a $(LIBMDDIR)/libmd.a $(TOOLS)

blackt:
	make -C${BLACKTDIR}

libmd:
	make -C${LIBMDDIR}

$(BLACKTDIR)/libblackt.a: $(BLACKTDIR)/src/**/*.cpp
	make -C ${BLACKTDIR} all

$(LIBMDDIR)/libmd.a: $(LIBMDDIR)/src/**/*.cpp
	make -C ${LIBMDDIR} all

$(TOOLS): $(SRCDIR)/$$@.cpp $(LIBDEPS) $(BLACKTDIR)/libblackt.a
	$(CXX) $(SRCDIR)/$@.cpp $(OBJ) -o $(notdir $@) $(CXXFLAGS)

.PHONY: cleanme clean

cleanme:
	rm -f $(TOOLS)

clean: cleanme
#	rm -f $(LIB)
#	rm -rf $(ODIR)
	make -C ${BLACKTDIR} clean
	make -C ${LIBMDDIR} clean
