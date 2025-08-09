TERMUX_PKG_HOMEPAGE=https://www.perl.org/
TERMUX_PKG_DESCRIPTION="Capable, feature-rich programming language"
TERMUX_PKG_LICENSE="Artistic-License-2.0"
TERMUX_PKG_MAINTAINER="@termux"
# Packages which should be rebuilt after version change:
# - exiftool
# - irssi
# - libapt-pkg-perl
# - libregexp-assemble-perl
# - psutils
# - subversion
TERMUX_PKG_VERSION=5.38.4
TERMUX_PKG_SRCURL="https://github.com/Perl/perl5/archive/refs/tags/v5.38.4.tar.gz"
TERMUX_PKG_SHA256=e63ee4f816ccdba64cecf9036a80da645b79519bf54e4c89832497a16088556e
TERMUX_PKG_DEPENDS=libandroid-utimes
TERMUX_PKG_BUILD_IN_SRC=true

termux_step_configure() {
		cd $TERMUX_PKG_BUILDDIR
		CFLAGS+=" -D__USE_GNU" LDFLAGS=" -Wl,-rpath=$TERMUX_PREFIX/lib -L$TERMUX_PREFIX/lib -landroid-utimes -lm -llog -L/system/lib64" $TERMUX_PKG_SRCDIR/Configure \
			-des \
			-Dusedl \
			-Dusemultiplicity \
			-Duserelocatableinc=no \
			-Duseshrplib \
			-Duseithreads \
			-Dusethreads \
			-Alibpth='/system/lib64/ /vendor/lib/' \
			-Dsysroot=$TERMUX_PREFIX \
			-Dprefix=$TERMUX_PREFIX \
			-Dld="cc -Wl,-rpath=$TERMUX_PREFIX/lib -Wl,--enable-new-dtags -L/system/lib64/" \
			-Dcc="cc -L/system/lib64/" \
			-Doptimize="-O2"
}

termux_step_make() {
	echo '#undef __USE_GNU' >> $TERMUX_PKG_SRCDIR/config.h
	echo '#define __USE_GNU' >> $TERMUX_PKG_SRCDIR/config.h
	echo '#undef HAS_NL_LANGINFO' >> $TERMUX_PKG_SRCDIR/config.h
	echo '#define HAS_NL_LANGINFO' >> $TERMUX_PKG_SRCDIR/config.h
	echo '#undef I_FCNTL' >> $TERMUX_PKG_SRCDIR/config.h
	echo '#define I_FCNTL' >> $TERMUX_PKG_SRCDIR/config.h

	make -j $TERMUX_PKG_MAKE_PROCESSES
}

termux_step_post_make_install() {
	pushd $TERMUX_PREFIX/lib
	ln -f -s perl5/${TERMUX_PKG_VERSION}/${TERMUX_ARCH}-linux-android-thread-multi/CORE/libperl.so libperl.so
	popd

	pushd $TERMUX_PREFIX/include
	ln -f -s ../lib/perl5/${TERMUX_PKG_VERSION}/${TERMUX_ARCH}-linux-android-thread-multi/CORE perl
	popd
	pushd $TERMUX_PREFIX/bin
	ln -sf perl${TERMUX_PKG_VERSION} perl
	popd
}
