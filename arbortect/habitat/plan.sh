pkg_name=arbortect
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_version="0.0.1"
pkg_description="A tool for configuring Hubs Clud"

pkg_deps=(
  core/coreutils
  core/node/12.9.0
)

pkg_build_deps=(
  core/git
)

do_prepare() {
  # we need /usr/bin/env for webpack CLI
  [[ ! -f /usr/bin/env ]] && ln -s "$(pkg_path_for coreutils)/bin/env" /usr/bin/env
  return 0;
}

do_build() {
  npm ci && npm run build
}

do_install() {
  # take care not to include unminified arbortect source
  for p in node_modules dist
  do
    cp -R ./$p "$pkg_prefix"
  done
}

do_strip() {
  return 0;
}
