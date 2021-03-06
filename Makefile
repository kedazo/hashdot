# JDK used for compiling, a different one can be set at runtime,
# see profiles/default.hdp
JAVA_HOME?=$(realpath $(dir $(shell which java))/..)

# Dependent on apache portable runtime (apr-devel-1.x apr-1.x)
APR_CONFIG=$(shell which apr-1-config)

# Install hashdot binaries to specified directory
INSTALL_BIN?=/opt/bin

# The set of symlinks (from all below) to insall
INSTALL_SYMLINKS = jruby

# Where to install and find profiles (*.hdp)
# export PROFILE_DIR=./profiles to work in source directory
PROFILE_DIR?=/opt/hashdot/profiles

VERSION=1.4.0

CC=gcc
CFLAGS=$(shell ${APR_CONFIG} --cflags --cppflags --includes) -O2 -Wall -fno-strict-aliasing -g \
-I$(JAVA_HOME)/include \
-I$(JAVA_HOME)/include/linux \
-DHASHDOT_PROFILE_DIR=\"${PROFILE_DIR}\" \
-DHASHDOT_VERSION=\"${VERSION}\"

# Override platform default (i.e. Mac defaults x32)
# LDFLAGS += -m64

LDFLAGS=$(shell ${APR_CONFIG} --ldflags)
LDLIBS=$(shell ${APR_CONFIG} --libs --link-ld)

ALL_SYMLINKS = clj jruby jython groovy rhino scala

all: hashdot

OBJS = runtime.o daemon.o jvm.o libpath.o main.o pidfile.o property.o

hashdot: $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS) $(LDLIBS)

Makefile.deps : $(OBJS:%.o=%.c) *.h
	$(CC) -MM $(CFLAGS) $(OBJS:%.o=%.c) > $@

# Install to INSTALL_BIN and PROFILE_DIR
install: hashdot
	install -d $(INSTALL_ROOT)$(PROFILE_DIR)
	install -m 644 profiles/*.hdp $(INSTALL_ROOT)$(PROFILE_DIR)
	install -d $(INSTALL_ROOT)$(INSTALL_BIN)
	install -m 755 hashdot $(INSTALL_ROOT)$(INSTALL_BIN)
	cd $(INSTALL_ROOT)$(INSTALL_BIN) && \
	for sl in $(INSTALL_SYMLINKS); do \
		test -e $$sl || ln -s hashdot $$sl; \
	done

dist: hashdot
	mkdir hashdot-$(VERSION)
	cp -a INSTALL Makefile *.c *.h profiles test doc examples hashdot-$(VERSION)
	tar --exclude '.svn' --exclude '*~' -zcvf hashdot-$(VERSION)-src.tar.gz hashdot-$(VERSION)
	rm -rf hashdot-$(VERSION)

publish: dist
	rsync -auP hashdot-$(VERSION)-src.tar.gz  dekellum@frs.sourceforge.net:uploads/
	rsync -aP --exclude ’*~’ doc/ dekellum,hashdot@web.sourceforge.net:/home/groups/h/ha/hashdot/htdocs/

$(ALL_SYMLINKS): hashdot
	ln -sf hashdot $@

test/foo/Bar.class test/foobar.jar : test/foo/Bar.java
	$(JAVA_HOME)/bin/javac $^
	$(JAVA_HOME)/bin/jar -cf test/foobar.jar -C test foo

CPATH_TESTS = $(wildcard test/test_class_path_?.rb)

test: hashdot jruby test/foo/Bar.class test/foobar.jar
	test/error/error_tests.sh
	test/test_props.rb
	test/test_env.rb
	test/test_chdir.rb
	@for tst in $(CPATH_TESTS); do echo $$tst; $$tst; done
	test/test_daemon.rb
	test/test_cmdline.rb param1 param2 || true
	test/test_pid_file

# Requires all profiles working
EXAMPLES = $(wildcard examples/*)
test-examples : $(ALL_SYMLINKS)
	@for example in $(EXAMPLES); do echo $$example; $$example; done

clean:
	rm -rf hashdot-$(VERSION)-src.tar.gz hashdot hashdot.dSYM
	rm -rf $(ALL_SYMLINKS)
	rm -rf *.o
	rm -rf test/foobar.jar
	-rm -rf Makefile.deps

include Makefile.deps

.PHONY : test test-examples all install dist publish
