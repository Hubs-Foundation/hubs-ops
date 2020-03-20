pkg_name=libconfig
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="1.7.2"
pkg_license=('BSD')
pkg_source="https://hyperrealm.github.io/libconfig/dist/libconfig-${pkg_version}.tar.gz"
pkg_filename="${pkg_name}-${pkg_version}.tar.gz"
pkg_shasum="7c3c7a9c73ff3302084386e96f903eb62ce06953bb1666235fac74363a16fad9"
pkg_build_deps=(core/make core/gcc)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_lib_dirs=(lib)
pkg_pconfig_dirs=(lib/pkgconfig)
pkg_description="Libconfig is a simple library for processing structured configuration files"
pkg_upstream_url="https://hyperrealm.github.io/libconfig/"
