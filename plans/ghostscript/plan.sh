pkg_origin=mozillareality
pkg_name=ghostscript
pkg_version=9.22

pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_license=('AGPLv3')
pkg_description="Ghostscript is a versatile processor for PostScript data with the ability to render PostScript to different targets."
pkg_upstream_url=https://www.ghostscript.com/
pkg_source=https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs922/${pkg_name}-${pkg_version}.tar.gz
pkg_shasum=7f5f4487c0df9dce37481e4c8f192c0322e4c69f5a2ba900a7833c992331bcf4
pkg_deps=(
  core/glib
  core/glibc # https://github.com/habitat-sh/habitat/issues/3303
  core/fontconfig
  core/freetype
  core/libjpeg-turbo
  core/libpng
  core/libtiff
  core/lcms2
  core/zlib
  core/openjpeg
)
pkg_build_deps=(
  core/coreutils
  core/m4
  core/diffutils
  core/patch
  core/make
  core/gcc
  core/libtool
  core/pkg-config
  core/automake
  core/autoconf
)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_lib_dirs=(lib)
pkg_pconfig_dirs=(lib/pkgconfig)

do_build() {
  rm -rf freetype lcms2 jpeg libpng tiff zlib openjpeg

  ./configure --prefix=${pkg_prefix} --disable-compile-inits --enable-dynamic --with-system-libtiff --disable-cups
  make
  make so
}

do_install() {
  make install
  make soinstall

  install -v -m644 base/*.h ${pkg_prefix}/include/ghostscript
  ln -v -s ghostscript ${pkg_prefix}/include/ps
}
