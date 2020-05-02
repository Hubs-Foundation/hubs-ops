pkg_name=youtube-dl-api-server
pkg_version=0.4
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_license=('unlicense')
pkg_description="A youtube-dl REST API server"
pkg_upstream_url="https://github.com/mozillareality/youtube-dl-api-server"
pkg_source="https://github.com/mozillareality/youtube-dl-api-server/archive/${pkg_version}.tar.gz"
pkg_shasum="6107513539ac18ef14377a0ecea55e54248e0113d7bef479da98a3dc19dad8d1"
pkg_deps=(
  core/envdir/1.0.1/20200404003559
  core/lzop/1.04/20200404063539
  core/pv1.6.0/20200403140749
  core/python/3.7.0/20200310040007
)
pkg_bin_dirs=(bin)

do_prepare() {
  pyvenv "$pkg_prefix"
  source "$pkg_prefix/bin/activate"
}

do_build() {
  python setup.py sdist
}

do_install() {
  pip install "dist/youtube_dl_server-${pkg_version}.tar.gz"
  pip install gunicorn
  rm -rf dist build

  # Write out versions of all pip packages to package
  pip freeze > "$pkg_prefix/requirements.txt"
}
