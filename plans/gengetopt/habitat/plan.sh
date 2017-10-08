pkg_name=gengetopt
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="2.22.6"
pkg_license=('GPL')
pkg_source="ftp://ftp.gnu.org/gnu/gengetopt/gengetopt-${pkg_version}.tar.gz"
pkg_shasum="30b05a88604d71ef2a42a2ef26cd26df242b41f5b011ad03083143a31d9b01f7"
pkg_filename="${pkg_name}-${pkg_version}.tar.gz"
pkg_build_deps=(core/make core/gcc)
pkg_bin_dirs=(bin)
pkg_description="Gengetopt is a tool to write command line option parsing code for C programs."
pkg_upstream_url="https://www.gnu.org/software/gengetopt/gengetopt.html"
