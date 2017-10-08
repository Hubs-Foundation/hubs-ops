pkg_name=libwebsockets
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="2.3.0"
pkg_source="https://github.com/warmcat/libwebsockets/archive/v2.3.0.tar.gz"
pkg_shasum="f08a8233ca1837640b72b1790cce741ce4b0feaaa6b408fe28a303cbf0408fa1"
pkg_license=('LGPL-2.1')
pkg_build_deps=(core/make core/gcc core/cmake core/openssl core/git)
pkg_deps=(core/zlib)
pkg_lib_dirs=(lib)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_description="This is the libwebsockets C library for lightweight websocket clients and servers."
pkg_upstream_url="https://github.com/warmcat/libwebsockets"

do_build() {
  mkdir build
  cd build

  cmake \
    -DCMAKE_INSTALL_PREFIX:PATH=${pkg_prefix} \
    -DZLIB_ROOT=$(pkg_path_for core/zlib) \
    -DOPENSSL_ROOT_DIR=$(pkg_path_for core/openssl) ..

  make
}

do_install() {
  cd build
  do_default_install
}
