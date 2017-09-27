pkg_origin=mozillareality
pkg_name=libidn2
pkg_version=2.0.2

pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_license=('LGPLv2.1+')
pkg_description="Libidn2 is an implementation of the IDNA2008 + TR46 "\
"specifications (RFC 5890, RFC 5891, RFC 5892, RFC 5893, TR 46)"
pkg_upstream_url=https://www.gnu.org/software/libidn/#libidn2
pkg_source=https://ftp.gnu.org/gnu/libidn/${pkg_name}-${pkg_version}.tar.gz
pkg_shasum=8cd62828b2ab0171e0f35a302f3ad60c3a3fffb45733318b3a8205f9d187eeab
pkg_deps=(
  core/glibc
)
pkg_build_deps=(
  core/coreutils core/diffutils core/patch
  core/make core/gcc
)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_lib_dirs=(lib)
pkg_pconfig_dirs=(lib/pkgconfig)
