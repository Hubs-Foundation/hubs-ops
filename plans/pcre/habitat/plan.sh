pkg_name=pcre
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"

pkg_version="8.41"
pkg_source="https://ftp.pcre.org/pub/pcre/pcre-8.41.tar.gz"
pkg_shasum="244838e1f1d14f7e2fa7681b857b3a8566b74215f28133f14a8f5e59241b682c"
pkg_build_deps=(core/make core/gcc) 
pkg_description="The PCRE library is a set of functions that implement regular expression pattern matching using the same syntax and semantics as Perl 5."
pkg_upstream_url="http://www.pcre.org/"
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)
