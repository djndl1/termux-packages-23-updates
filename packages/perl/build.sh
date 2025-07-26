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
TERMUX_PKG_SRCURL="https://www.cpan.org/src/5.0/perl-5.38.4.tar.gz"
TERMUX_PKG_SHA256=e63ee4f816ccdba64cecf9036a80da645b79519bf54e4c89832497a16088556e
TERMUX_PKG_DEPENDS=libandroid-utimes
TERMUX_PKG_BUILD_IN_SRC=true

termux_step_configure() {
		cd $TERMUX_PKG_BUILDDIR
		CFLAGS=" -D__USE_BSD=1" LDFLAGS=" -Wl,-rpath=$TERMUX_PREFIX/lib -L$TERMUX_PREFIX/lib -landroid-utimes -lm" $TERMUX_PKG_SRCDIR/configure \
			-Dsysroot=$TERMUX_PREFIX \
			-Dprefix=$TERMUX_PREFIX \
			-Dsh=$TERMUX_PREFIX/bin/sh \
			-Dld="$CC -Wl,-rpath=$TERMUX_PREFIX/lib -Wl,--enable-new-dtags" \
			-Duseshrplib \
			-Duseithreads \
			-Dusemultiplicity \
			-Doptimize="-O2" \
			--with-libs="-lm -L$TERMUX_PREFIX/lib -landroid-utimes"
}

termux_step_post_make_install() {
	cd $TERMUX_PREFIX/share/man/man1
	rm perlbug.1
	ln -s perlthanks.1 perlbug.1
	cd $TERMUX_PREFIX/bin
	rm perlbug
	ln -s perlthanks perlbug

	cd $TERMUX_PREFIX/lib
	ln -f -s perl5/${TERMUX_PKG_VERSION}/${TERMUX_ARCH}-android/CORE/libperl.so libperl.so

	cd $TERMUX_PREFIX/include
	ln -f -s ../lib/perl5/${TERMUX_PKG_VERSION}/${TERMUX_ARCH}-android/CORE perl
}
