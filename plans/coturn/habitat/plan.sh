pkg_name=coturn
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_version=4.5.0.7
pkg_license=("GPLv3")
pkg_source="https://github.com/coturn/coturn/archive/${pkg_version}.tar.gz"
pkg_filename="${pkg_name}-${pkg_version}.tar.gz"
pkg_shasum=6a4e802e4e7a8b7aeb76f0c4a4153da64615eac9db7c320b599fae86c46183ae
pkg_deps=(core/openssl mozillareality/libevent)
pkg_build_deps=(core/gcc core/make)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_lib_dirs=(lib)
pkg_description="Free, open source TURN and STUN server."
pkg_upstream_url="https://github.com/coturn/coturn"

do_build() {
    ./configure --prefix=${pkg_prefix}
    make
}

do_check() {
    ./examples/scripts/rfc5769.sh
}
