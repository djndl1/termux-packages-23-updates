TERMUX_PKG_HOMEPAGE=https://developer.android.com/tools/sdk/ndk/index.html
TERMUX_PKG_DESCRIPTION="System header and library files from the Android NDK needed for compiling C programs"
TERMUX_PKG_LICENSE="NCSA"
TERMUX_PKG_MAINTAINER="@termux"
# Version should be equal to TERMUX_NDK_{VERSION_NUM,REVISION} in
# scripts/properties.sh
TERMUX_PKG_VERSION=23c
TERMUX_PKG_SRCURL=file://${TERMUX_PKG_BUILDER_DIR}/../dummy.tar.xz
TERMUX_PKG_SHA256=
TERMUX_PKG_AUTO_UPDATE=false
# This package has taken over <pty.h> from the previous libutil-dev
# and iconv.h from libandroid-support-dev:
TERMUX_PKG_CONFLICTS="libutil-dev, libgcc, libandroid-support-dev"
TERMUX_PKG_REPLACES="libutil-dev, libgcc, libandroid-support-dev, ndk-stl"
TERMUX_PKG_NO_STATICSPLIT=true
TERMUX_PKG_BUILD_IN_SRC=true
termux_step_get_source() {
	      mkdir -p "$TERMUX_PKG_SRCDIR"
                termux_download_src_archive
                cd $TERMUX_PKG_TMPDIR
                termux_extract_src_archive
}
