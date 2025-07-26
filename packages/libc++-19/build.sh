TERMUX_PKG_HOMEPAGE=https://clang.llvm.org/
TERMUX_PKG_DESCRIPTION="Custom built libc++"
TERMUX_PKG_LICENSE="Apache-2.0, NCSA"
TERMUX_PKG_LICENSE_FILE="llvm/LICENSE.TXT"
TERMUX_PKG_MAINTAINER="@finagolfin"
# Keep flang version and revision in sync when updating (enforced by check in termux_step_pre_configure).
LLVM_MAJOR_VERSION=19
TERMUX_PKG_VERSION=${LLVM_MAJOR_VERSION}.1.7
TERMUX_PKG_SHA256=82401fea7b79d0078043f7598b835284d6650a75b93e64b6f761ea7b63097501
TERMUX_PKG_AUTO_UPDATE=false
TERMUX_PKG_SRCURL=https://github.com/llvm/llvm-project/releases/download/llvmorg-$TERMUX_PKG_VERSION/llvm-project-${TERMUX_PKG_VERSION}.src.tar.xz
TERMUX_PKG_HOSTBUILD=false
TERMUX_PKG_RM_AFTER_INSTALL=""
TERMUX_PKG_DEPENDS="libc++, libffi, libxml2, ncurses, zlib, zstd"
TERMUX_PKG_BUILD_DEPENDS="binutils-libs"
# Replace gcc since gcc is deprecated by google on android and is not maintained upstream.
# Conflict with clang versions earlier than 3.9.1-3 since they bundled llvm.
TERMUX_PKG_CONFLICTS="gcc, clang (<< 3.9.1-3)"
TERMUX_PKG_BREAKS="libclang, libclang-dev, libllvm-dev"
TERMUX_PKG_REPLACES="gcc, libclang, libclang-dev, libllvm-dev"
TERMUX_PKG_GROUPS="base-devel"
# See http://llvm.org/docs/CMake.html:
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-DANDROID_PLATFORM_LEVEL=$TERMUX_PKG_API_LEVEL
-DLLVM_ENABLE_PIC=ON
-DLLVM_ENABLE_RUNTIMES=libcxx;libcxxabi;libunwind
-DLIBCXX_SHARED_OUTPUT_NAME=c++-19
-DLLVM_INCLUDE_TESTS=OFF
-DDEFAULT_SYSROOT=$(dirname $TERMUX_PREFIX/)
-DLLVM_TARGETS_TO_BUILD=AArch64
-DLIBCXX_INCLUDE_TESTS=OFF
-DLIBCXX_INSTALL_INCLUDE_DIR=include/c++/19/v1
-DLIBCXX_INSTALL_INCLUDE_TARGET_DIR=include/c++/19/v1
-DLLVM_ENABLE_SPHINX=OFF
-DSPHINX_OUTPUT_MAN=OFF
-DSPHINX_WARNINGS_AS_ERRORS=OFF
"

if [ x$TERMUX_ARCH_BITS = x32 ]; then
	# Do not set _FILE_OFFSET_BITS=64
	TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" -DLLVM_FORCE_SMALLFILE_FOR_ANDROID=on"
fi

TERMUX_PKG_FORCE_CMAKE=true
TERMUX_PKG_HAS_DEBUG=false
# Debug build succeeds but make install with:
# cp: cannot stat '../src/projects/openmp/runtime/exports/common.min.50.ompt.optional/include/omp.h': No such file or directory
# common.min.50.ompt.optional should be common.deb.50.ompt.optional when doing debug build
#
termux_step_make() {
	export LDFLAGS+=' -llog'
	ninja cxx cxxabi unwind
}

termux_step_pre_configure() {
	# Add unknown vendor, otherwise it screws with the default LLVM triple
	# detection.
	export LLVM_DEFAULT_TARGET_TRIPLE=${TERMUX_HOST_PLATFORM/-/-unknown-}
	export LLVM_TARGET_ARCH
	if [ $TERMUX_ARCH = "arm" ]; then
		LLVM_TARGET_ARCH=ARM
	elif [ $TERMUX_ARCH = "aarch64" ]; then
		LLVM_TARGET_ARCH=AArch64
	elif [ $TERMUX_ARCH = "i686" ] || [ $TERMUX_ARCH = "x86_64" ]; then
		LLVM_TARGET_ARCH=X86
	else
		termux_error_exit "Invalid arch: $TERMUX_ARCH"
	fi
	# see CMakeLists.txt and tools/clang/CMakeLists.txt
	TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" -DLLVM_TARGET_ARCH=$LLVM_TARGET_ARCH"
	TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" -DLLVM_HOST_TRIPLE=$LLVM_DEFAULT_TARGET_TRIPLE"
	export TERMUX_SRCDIR_SAVE=$TERMUX_PKG_SRCDIR
	TERMUX_PKG_SRCDIR=$TERMUX_PKG_SRCDIR/llvm
}

termux_step_post_configure() {
	TERMUX_PKG_SRCDIR=$TERMUX_SRCDIR_SAVE
}

termux_step_make_install() {
	ninja install-cxx install-cxxabi install-unwind
}

termux_step_post_make_install() {
	:
}
