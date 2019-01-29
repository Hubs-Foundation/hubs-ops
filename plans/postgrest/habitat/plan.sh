pkg_name=postgrest
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_version=5.2.0
pkg_bin_dirs=(bin)

pkg_deps=(
  core/gcc-libs
  core/glibc
  core/openssl
  core/zlib
  core/libpq
  core/cacerts
)

pkg_build_deps=(
  core/curl
)

do_build() {
  return 0
}

do_install() {
  curl -SLO "https://github.com/PostgREST/postgrest/releases/download/v${pkg_version}/postgrest-v${pkg_version}-ubuntu.tar.xz" && tar xfvJ postgrest-v${pkg_version}-ubuntu.tar.xz && mv postgrest ${pkg_prefix}/bin
  return 0
}
