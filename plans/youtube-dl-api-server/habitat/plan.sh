pkg_name=youtube-dl-api-server
pkg_version=0.5
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_license=('unlicense')
pkg_description="A youtube-dl REST API server"
pkg_upstream_url="https://github.com/mozillareality/youtube-dl-api-server"
pkg_deps=(
  core/envdir/1.0.1/20190305224317
  core/lzop/1.04/20190116190143
  core/pv/1.6.0/20190116190154
  core/python/3.7.0/20190305212847 
)
pkg_bin_dirs=(bin)

do_prepare() {
  pyvenv "$pkg_prefix"
  source "$pkg_prefix/bin/activate"
}

do_build() {
  # python setup.py sdist
  echo "ffffffffffffffff"
}

do_install() {
  cp -R ./ytdl-api/*.py ${pkg_prefix}
  cp -R ./ytdl-api-deps/* ${pkg_prefix}/
  pip install gunicorn
  rm -rf dist build

  # Write out versions of all pip packages to package
  pip freeze > "$pkg_prefix/requirements.txt"

  ls -lha ${pkg_prefix}

}
