pkg_name=telegraf
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_version="1.13.4"
pkg_license=('MIT')
pkg_description="telegraf - client for InfluxDB"
pkg_upstream_url="https://github.com/influxdata/telegraf/"
pkg_source="https://dl.influxdata.com/${pkg_name}/releases/${pkg_name}-${pkg_version}-static_linux_amd64.tar.gz"
pkg_shasum="ec9d0cb7289df3ac0059d4d41c680a45455f452618318483c93784087ebb7c1c"
pkg_build_deps=(core/wget core/tar)
pkg_deps=()
pkg_bin_dirs=(bin)

do_build() {
  return 0
}

do_install() {
  install -vD "${HAB_CACHE_SRC_PATH}/telegraf/telegraf" "${pkg_prefix}/bin/telegraf"
}
