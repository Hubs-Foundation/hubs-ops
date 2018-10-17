pkg_name=net-snmp
pkg_origin=smartb
pkg_version="5.7.3"
pkg_maintainer="Mozilla Mixed Reality <mozillareality@mozilla.com>"
pkg_license=('BSD')
pkg_source="https://downloads.sourceforge.net/project/$pkg_name/$pkg_name/$pkg_version/$pkg_name-$pkg_version.zip"
pkg_shasum="e8dfc79b6539b71a6ff335746ce63d2da2239062ad41872fff4354cafed07a3e"
pkg_build_deps=(core/make core/gcc)
pkg_lib_dirs=(lib)
pkg_include_dirs=(include)
pkg_bin_dirs=(bin)
pkg_description="Simple Network Management Protocol (SNMP) is a widely used protocol for monitoring the health and welfare of network equipment."
pkg_upstream_url="http://www.net-snmp.org/"

do_build() {
  ./configure --prefix=$pkg_prefix \
  --with-sys-contact="admin@example.com" \
  --with-default-snmp-version="3" \
  --with-sys-location="example_location" \
  --with-logfile="none" \
  --with-persistent-directory="$pkg_svc_data_path"
  make
}
