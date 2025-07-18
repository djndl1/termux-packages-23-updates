TERMUX_PKG_HOMEPAGE=https://www.gnu.org/software/gawk/
TERMUX_PKG_DESCRIPTION="Programming language designed for text processing"
TERMUX_PKG_LICENSE="GPL-3.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="5.3.1"
TERMUX_PKG_SRCURL=https://mirrors.kernel.org/gnu/gawk/gawk-${TERMUX_PKG_VERSION}.tar.xz
TERMUX_PKG_SHA256=694db764812a6236423d4ff40ceb7b6c4c441301b72ad502bb5c27e00cd56f78
TERMUX_PKG_AUTO_UPDATE=false
TERMUX_PKG_DEPENDS="libandroid-support, libgmp, libmpfr, readline"
TERMUX_PKG_BREAKS="gawk-dev"
TERMUX_PKG_REPLACES="gawk-dev"
TERMUX_PKG_ESSENTIAL=true
TERMUX_PKG_RM_AFTER_INSTALL="bin/gawk-* bin/igawk share/man/man1/igawk.1"
TERMUX_PKG_GROUPS="base-devel"
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--disable-pma
"

termux_step_pre_configure() {
	# Certain packages are not safe to build on device because their
	# build.sh script deletes specific files in $TERMUX_PREFIX.
	#if $TERMUX_ON_DEVICE_BUILD; then
	#	termux_error_exit "Package '$TERMUX_PKG_NAME' is not safe for on-device builds."
	#fi

	# Remove old symlink to force a fresh timestamp:
	mv $TERMUX_PREFIX/bin/awk $TERMUX_PREFIX/bin/awk.orig

	# http://cross-lfs.org/view/CLFS-2.1.0/ppc64-64/temp-system/gawk.html
	cp -v extension/Makefile.in{,.orig}
	sed -e 's/check-recursive all-recursive: check-for-shared-lib-support/check-recursive all-recursive:/' extension/Makefile.in.orig > extension/Makefile.in
}
