TERMUX_PKG_HOMEPAGE=https://golang.org/
TERMUX_PKG_DESCRIPTION="Go programming language compiler"
TERMUX_PKG_LICENSE="BSD 3-Clause"
_MAJOR_VERSION=1.14.7
# Use the ~ deb versioning construct in the future:
TERMUX_PKG_VERSION=2:${_MAJOR_VERSION}
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL=https://storage.googleapis.com/golang/go${_MAJOR_VERSION}.src.tar.gz
TERMUX_PKG_SHA256=064392433563660c73186991c0a315787688e7c38a561e26647686f89b6c30e3
TERMUX_PKG_DEPENDS="clang"
TERMUX_PKG_NO_STATICSPLIT=true

termux_step_make_install() {
	termux_setup_golang

	TERMUX_GOLANG_DIRNAME=${GOOS}_$GOARCH
	TERMUX_GODIR=$TERMUX_PREFIX/lib/go

	cd $TERMUX_PKG_SRCDIR/src
	# Unset PKG_CONFIG to avoid the path being hardcoded into src/cmd/cgo/zdefaultcc.go,
	# see https://github.com/termux/termux-packages/issues/3505.
	env CC_FOR_TARGET=clang-10 \
	    CXX_FOR_TARGET=clang++-10 \
	    CC=clang-10 \
	    GO_LDFLAGS="-extldflags=-pie" \
	    GOROOT_BOOTSTRAP=$GOROOT \
	    GOROOT_FINAL=$TERMUX_GODIR \
	    PKG_CONFIG= \
	    ./make.bash

	cd ..
	rm -Rf $TERMUX_GODIR
	mkdir -p $TERMUX_GODIR/{bin,src,doc,lib,pkg/tool/$TERMUX_GOLANG_DIRNAME,pkg/include,pkg/${TERMUX_GOLANG_DIRNAME}}
	cp bin/$TERMUX_GOLANG_DIRNAME/{go,gofmt} $TERMUX_GODIR/bin/
	ln -sfr $TERMUX_GODIR/bin/go $TERMUX_PREFIX/bin/go
	ln -sfr $TERMUX_GODIR/bin/gofmt $TERMUX_PREFIX/bin/gofmt
	cp VERSION $TERMUX_GODIR/
	cp pkg/tool/$TERMUX_GOLANG_DIRNAME/* $TERMUX_GODIR/pkg/tool/$TERMUX_GOLANG_DIRNAME/
	cp -Rf src/* $TERMUX_GODIR/src/
	cp -Rf doc/* $TERMUX_GODIR/doc/
	cp pkg/include/* $TERMUX_GODIR/pkg/include/
	cp -Rf lib/* $TERMUX_GODIR/lib
	cp -Rf pkg/${TERMUX_GOLANG_DIRNAME}/* $TERMUX_GODIR/pkg/${TERMUX_GOLANG_DIRNAME}/
}

termux_step_post_massage() {
	find . -path '*/testdata*' -delete
}
