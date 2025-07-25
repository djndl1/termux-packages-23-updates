TERMUX_PKG_HOMEPAGE=https://www.gnu.org/software/coreutils/
TERMUX_PKG_DESCRIPTION="Basic file, shell and text manipulation utilities from the GNU project"
TERMUX_PKG_LICENSE="GPL-3.0"
TERMUX_PKG_MAINTAINER="Joshua Kahn @TomJo2000"
TERMUX_PKG_VERSION=9.7
TERMUX_PKG_SRCURL=https://mirrors.kernel.org/gnu/coreutils/coreutils-${TERMUX_PKG_VERSION}.tar.xz
TERMUX_PKG_SHA256=e8bb26ad0293f9b5a1fc43fb42ba970e312c66ce92c1b0b16713d7500db251bf
TERMUX_PKG_DEPENDS="libandroid-selinux, libandroid-support, libgmp, libiconv"
TERMUX_PKG_BREAKS="chroot, busybox (<< 1.30.1-4)"
TERMUX_PKG_REPLACES="chroot, busybox (<< 1.30.1-4)"
TERMUX_PKG_ESSENTIAL=true
# On device build is unsupported as it removes utility 'ln' (and maybe
# something else) in the installation process.

# pinky has no usage on Android.
# df does not work either, let system binary prevail.
# $PREFIX/bin/env is provided by busybox for shebangs to work directly.
# users and who doesn't work and does not make much sense for Termux.
# uptime is provided by procps.
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
gl_cv_host_operating_system=Android
ac_cv_func_getpass=yes
--disable-xattr
--enable-no-install-program=pinky,df,users,who,uptime
--enable-single-binary=symlinks
--with-gmp
"

termux_step_pre_configure() {
	# https://android.googlesource.com/platform/bionic/+/master/docs/32-bit-abi.md#is-32_bit-on-lp32-y2038
	if [[ "$TERMUX_ARCH_BITS" == '32' ]]; then
		TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" --disable-year2038"
	fi

	CPPFLAGS+=" -D__USE_FORTIFY_LEVEL=0"
	LDFLAGS+=" -landroid-selinux"
}
