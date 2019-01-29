pkg_name=haskell-stack
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_version=1.6.5
pkg_source=https://github.com/commercialhaskell/stack/releases/download/v${pkg_version}/stack-${pkg_version}-linux-x86_64-static.tar.gz
pkg_shasum=f8876fa73c4bb95c1d762073af2dfa4a003d795709ec3fee2f9743ca6a5fedc6
pkg_bin_dirs=(bin)

pkg_deps=(
  mozillareality/ghc
  core/glibc
  core/cacerts
  core/coreutils
  core/gawk
  core/sed
  core/perl
  core/make
  core/tar
  core/xz
  core/zlib
  core/gmp
  core/gnupg
  core/libffi
  core/gcc
)

do_unpack() {
  local source_dir=$HAB_CACHE_SRC_PATH/${pkg_dirname}

  mkdir -p "$source_dir"

  pushd "$source_dir" >/dev/null
  tar xz --strip-components=1 -f "$HAB_CACHE_SRC_PATH/$pkg_filename"
  popd > /dev/null

  return 0
}

do_build() {
  return 0
}

do_install() {
  cp -vr ./* "$pkg_prefix"

  # generate wrapper script to provide path to root certificates
  mkdir -p $pkg_prefix/bin

  cat > "$pkg_prefix/bin/stack" <<- EOM
#!/bin/sh

mkdir -p ~/.stack/programs/x86_64-linux
ln -sf "$(pkg_path_for ghc)" ~/.stack/programs/x86_64-linux/ghc-${ghc_version}
echo "installed" > ~/.stack/programs/x86_64-linux/ghc-${ghc_version}.installed

export SYSTEM_CERTIFICATE_PATH="$(pkg_path_for cacerts)/ssl/certs"

#fix trouble stack has finding awk
export AWK="$(pkg_path_for gawk)/bin/awk"

# fix trouble stack has finding libgmp
export LIBRARY_PATH="\$LIBRARY_PATH:${LD_RUN_PATH}"
export LD_LIBRARY_PATH="\$LD_LIBRARY_PATH:${LD_RUN_PATH}"
export LD_RUN_PATH="\$LD_RUN_PATH:${LD_RUN_PATH}"

exec $pkg_prefix/stack \$@
EOM

  chmod +x "$pkg_prefix/bin/stack"
}

do_strip() {
  # skip stripping binary as it may cause issues with patched binaries
  return 0
}
