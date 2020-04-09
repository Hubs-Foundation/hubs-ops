pkg_name=libwebsockets
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="2.4.2"
pkg_source="https://github.com/warmcat/libwebsockets/archive/v2.4.2.tar.gz"
pkg_shasum="73012d7fcf428dedccc816e83a63a01462e27819d5537b8e0d0c7264bfacfad6"
pkg_license=('LGPL-2.1')
pkg_build_deps=(core/make core/gcc core/cmake core/openssl core/git)
pkg_deps=(mozillareality/zlib)
pkg_lib_dirs=(lib)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_description="This is the libwebsockets C library for lightweight websocket clients and servers."
pkg_upstream_url="https://github.com/warmcat/libwebsockets"

do_build() {
  mkdir build
  cd build

  # see https://github.com/meetecho/janus-gateway/issues/732 re: LWS_MAX_SMP

  CFLAGS="${CFLAGS} -O2 -g" cmake \
    -DCMAKE_INSTALL_PREFIX:PATH=${pkg_prefix} \
    -DZLIB_ROOT=$(pkg_path_for mozillareality/zlib) \
    -DLWS_MAX_SMP=1 \
    -DLWS_WITHOUT_TESTAPPS=ON \
    -DCMAKE_C_FLAGS="-fpic" \
    -DOPENSSL_ROOT_DIR=$(pkg_path_for core/openssl) ..

  make
}

do_install() {
  cd build
  do_default_install
}
