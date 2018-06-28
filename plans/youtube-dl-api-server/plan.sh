pkg_name=youtube-dl-api-server
pkg_version=0.3
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_license=('unlicense')
pkg_description="A youtube-dl REST API server"
pkg_upstream_url="https://github.com/jaimeMF/youtube-dl-api-server"
pkg_source="https://github.com/jaimeMF/youtube-dl-api-server/archive/${pkg_version}.tar.gz"
pkg_shasum="5041e02aad851ce9f72419c4e442d730f6de2ad895057002720d2b1e8464b275"
pkg_deps=(core/envdir core/lzop core/pv core/python)
pkg_bin_dirs=(bin)

do_download() {
  return 0
}

do_verify() {
  return 0
}

do_unpack() {
  return 0
}

do_prepare() {
  pyvenv "$pkg_prefix"
  source "$pkg_prefix/bin/activate"
}

do_build() {
  return 0
}

do_install() {
  pip install --pre "youtube_dl_server==$pkg_version"
  pip install gunicorn

  # Write out versions of all pip packages to package
  pip freeze > "$pkg_prefix/requirements.txt"
}
