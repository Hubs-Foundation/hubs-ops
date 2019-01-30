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
  core/gmp
  core/cacerts
)

pkg_build_deps=(
  core/curl
  core/patchelf
)

do_build() {
  return 0
}

do_unpack() {
  mkdir -p "${HAB_CACHE_SRC_PATH}/${pkg_dirname}"

  curl -SLO "https://github.com/PostgREST/postgrest/releases/download/v${pkg_version}/postgrest-v${pkg_version}-ubuntu.tar.xz" && tar xfvJ postgrest-v${pkg_version}-ubuntu.tar.xz \
    -C "${HAB_CACHE_SRC_PATH}/${pkg_dirname}" \
    --no-same-owner
}

do_prepare() {
  patchelf --set-rpath "$LD_RUN_PATH" "${HAB_CACHE_SRC_PATH}/${pkg_dirname}/postgrest"
  return 0
}

do_install() {
  mv "${HAB_CACHE_SRC_PATH}/${pkg_dirname}/postgrest" "${pkg_prefix}/bin"
  return 0
}

do_strip() {
  return 0
}
