pkg_name=imgproxy
pkg_description="Fast and secure standalone server for resizing and converting remote images"
pkg_upstream_url="https://github.com/imgproxy/imgproxy"
pkg_origin=mozillareality
pkg_version="v2.7.0"
pkg_maintainer=''
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_license=("MIT")
pkg_source="https://github.com/imgproxy/imgproxy"
pkg_bin_dirs=(bin)
pkg_deps=(core/glibc core/gcc-libs core/bash)
pkg_build_deps=(core/pkg-config)
pkg_scaffolding=core/scaffolding-go/0.2.0/20191203174400
scaffolding_go_base_path=github.com/imgproxy/imgproxy
scaffolding_go_build_deps=()

do_download() {
  # HACK: need to set CGO environment here since the download stage fails otherwise

  _build_environment
  export CGO_CFLAGS=$CFLAGS
  export CGO_LDFLAGS=$LDFLAGS

  do_default_download
}

do_build() {
  do_default_build
}

do_install() {
  mkdir -p "$pkg_prefix/lib"
  mkdir -p "$pkg_prefix/include"
  mkdir -p "$pkg_prefix/share"

  do_default_install
}
