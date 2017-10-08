pkg_name=libsrtp
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="2.1.0"
pkg_source="https://github.com/cisco/libsrtp/archive/v${pkg_version}.zip"
pkg_shasum="0885a868cbc3bc6593b2ac240687f42f2a5407374bde4e6d16bd3fbde5917e62"
pkg_build_deps=(core/make core/gcc core/openssl core/automake) 
pkg_description="This package provides an implementation of the Secure Real-time Transport Protocol (SRTP), the Universal Security Transform (UST), and a supporting cryptographic kernel."
pkg_upstream_url="https://github.com/cisco/libsrtp"
pkg_config_dirs=${pkg_prefix}
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)

do_build() {
  ./configure --prefix=${pkg_prefix} --enable-openssl 
  make shared_library
}
