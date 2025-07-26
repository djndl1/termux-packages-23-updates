TERMUX_PKG_HOMEPAGE=https://libcxx.llvm.org/
TERMUX_PKG_DESCRIPTION="C++ Standard Library"
TERMUX_PKG_LICENSE="NCSA"
TERMUX_PKG_MAINTAINER="@termux"
# Version should be equal to TERMUX_NDK_{VERSION_NUM,REVISION} in
# scripts/properties.sh
TERMUX_PKG_VERSION=23c
TERMUX_PKG_SRCURL=file://${TERMUX_PKG_BUILDER_DIR}/../dummy.tar.xz
TERMUX_PKG_SHA256=
TERMUX_PKG_AUTO_UPDATE=false
TERMUX_PKG_ESSENTIAL=true
TERMUX_PKG_BUILD_IN_SRC=true

termux_step_get_source() {
	      mkdir -p "$TERMUX_PKG_SRCDIR"
                termux_download_src_archive
                cd $TERMUX_PKG_TMPDIR
                termux_extract_src_archive
}
