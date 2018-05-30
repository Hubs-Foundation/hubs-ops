pkg_origin=mozillareality
pkg_name=libevent
pkg_version=2.1.8
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_license=('BSD-3-Clause')
pkg_upstream_url="https://github.com/libevent/libevent"
pkg_description="A build of libevent with OpenSSL support."
pkg_source=https://github.com/${pkg_name}/${pkg_name}/releases/download/release-${pkg_version}-stable/${pkg_name}-${pkg_version}-stable.tar.gz
pkg_shasum=965cc5a8bb46ce4199a47e9b2c9e1cae3b137e8356ffdad6d94d3b9069b71dc2
pkg_dirname=${pkg_name}-${pkg_version}-stable
pkg_deps=(core/openssl core/glibc core/zlib)
pkg_build_deps=(core/cacerts core/coreutils core/diffutils core/gcc core/make core/python2 core/which)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_lib_dirs=(lib)

do_build() {
    ./configure --prefix="${pkg_prefix}" --enable-openssl
    make
}

do_check() {
    make verify
}
