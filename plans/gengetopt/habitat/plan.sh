pkg_name=gengetopt
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="2.23"
pkg_license=('GPL')
pkg_source="ftp://ftp.gnu.org/gnu/gengetopt/gengetopt-${pkg_version}.tar.xz"
pkg_shasum="b941aec9011864978dd7fdeb052b1943535824169d2aa2b0e7eae9ab807584ac"
pkg_filename="${pkg_name}-${pkg_version}.tar.gz"
pkg_build_deps=(core/make core/gcc core/texinfo)
pkg_bin_dirs=(bin)
pkg_description="Gengetopt is a tool to write command line option parsing code for C programs."
pkg_upstream_url="https://www.gnu.org/software/gengetopt/gengetopt.html"
