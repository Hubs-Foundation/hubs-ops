pkg_name=dd-agent
pkg_origin=mozillareality
pkg_maintainer="Mozilla Mixed Reality <mozillareality@mozilla.com>"

pkg_version="6.5.2"
pkg_description="The Datadog Agent"
pkg_license=("BSD-3-Clause")
pkg_upstream_url="https://github.com/datadog/datadog-agent"
pkg_build_deps=(core/curl core/sed core/tar core/gcc core/postgresql95 core/go core/git core/pkg-config core/virtualenv)
pkg_deps=(core/python2 core/libffi core/busybox-static core/openssl core/sysstat mozillareality/net-snmp core/zlib)
pkg_dirname="datadog-agent"
pkg_bin_dirs=(bin)

do_build() {
  export GOPATH="$PLAN_CONTEXT/go"
  mkdir -p "$GOPATH"
  
  export PATH=$PATH:$GOPATH/bin

  go get github.com/DataDog/gohai

  rm -rf $GOPATH/src/github.com/DataDog/datadog-agent

  export CGO_CFLAGS=$CFLAGS
  export CGO_LDFLAGS=$LDFLAGS

  git clone https://github.com/DataDog/datadog-agent.git $GOPATH/src/github.com/DataDog/datadog-agent
  cd $GOPATH/src/github.com/DataDog/datadog-agent
  pip install -r requirements.txt
  invoke deps
  invoke agent.build --use-embedded-libs
}

do_install() {
  mv "$GOPATH/src/github.com/DataDog/datadog-agent/bin/agent" "$pkg_prefix/bin"
  cp "$GOPATH/bin/gohai" "$pkg_prefix/bin"
}

do_strip() {
  return 0
}
