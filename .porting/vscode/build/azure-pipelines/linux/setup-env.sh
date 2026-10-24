#!/usr/bin/env bash

set -e

SYSROOT_ARCH=$VSCODE_ARCH
if [ "$SYSROOT_ARCH" == "x64" ]; then
  SYSROOT_ARCH="amd64"
fi

# New-world LoongArch builds use a locally provisioned sysroot.  Do this before
# the normal Microsoft sysroot download path, which intentionally has no
# Loong64 asset today.
if [ "$npm_config_arch" == "loong64" ]; then
  if [ -z "${VSCODE_LOONG64_SYSROOT_DIR:-}" ] || [ ! -d "$VSCODE_LOONG64_SYSROOT_DIR" ]; then
    echo "VSCODE_LOONG64_SYSROOT_DIR must point to a new-world LoongArch sysroot" >&2
    exit 1
  fi
  export VSCODE_CLIENT_SYSROOT_DIR="$VSCODE_LOONG64_SYSROOT_DIR"
  export VSCODE_REMOTE_SYSROOT_DIR="$VSCODE_LOONG64_SYSROOT_DIR"
else

export VSCODE_CLIENT_SYSROOT_DIR=$PWD/.build/sysroots/glibc-2.28-gcc-10.5.0
export VSCODE_REMOTE_SYSROOT_DIR=$PWD/.build/sysroots/glibc-2.28-gcc-8.5.0
if [ -d "$VSCODE_CLIENT_SYSROOT_DIR" ]; then
  echo "Using cached client sysroot"
else
  echo "Downloading client sysroot"
  SYSROOT_ARCH="$SYSROOT_ARCH" VSCODE_SYSROOT_DIR="$VSCODE_CLIENT_SYSROOT_DIR" node -e 'import { getVSCodeSysroot } from "./build/linux/debian/install-sysroot.ts"; (async () => { await getVSCodeSysroot(process.env["SYSROOT_ARCH"]); })()'
fi

if [ -d "$VSCODE_REMOTE_SYSROOT_DIR" ]; then
  echo "Using cached remote sysroot"
else
  echo "Downloading remote sysroot"
  SYSROOT_ARCH="$SYSROOT_ARCH" VSCODE_SYSROOT_DIR="$VSCODE_REMOTE_SYSROOT_DIR" VSCODE_SYSROOT_PREFIX="-glibc-2.28-gcc-8.5.0" node -e 'import { getVSCodeSysroot } from "./build/linux/debian/install-sysroot.ts"; (async () => { await getVSCodeSysroot(process.env["SYSROOT_ARCH"]); })()'
fi
fi

mkdir -p "$HOME/.gyp"
cat > "$HOME/.gyp/include.gypi" << 'EOF'
{
  "target_defaults": {
    "conditions": [
      ["OS=='linux'", {
        'cflags_cc!': [ '-std=gnu++20' ],
        'cflags_cc': [ '-std=gnu++2a' ],
      }]
    ]
  }
}
EOF

if [ "$npm_config_arch" == "x64" ]; then
  # Download clang based on chromium revision used by vscode
  curl -s https://raw.githubusercontent.com/chromium/chromium/150.0.7871.250/tools/clang/scripts/update.py | python - --output-dir=$PWD/.build/CR_Clang --host-os=linux

  # Download libcxx headers and objects from upstream electron releases
  DEBUG=libcxx-fetcher \
  VSCODE_LIBCXX_OBJECTS_DIR=$PWD/.build/libcxx-objects \
  VSCODE_LIBCXX_HEADERS_DIR=$PWD/.build/libcxx_headers  \
  VSCODE_LIBCXXABI_HEADERS_DIR=$PWD/.build/libcxxabi_headers \
  VSCODE_ARCH="$npm_config_arch" \
  node build/linux/libcxx-fetcher.ts

  # Set compiler toolchain
  # Flags for the client build are based on
  # https://source.chromium.org/chromium/chromium/src/+/refs/tags/150.0.7871.250:build/config/arm.gni
  # https://source.chromium.org/chromium/chromium/src/+/refs/tags/150.0.7871.250:build/config/compiler/BUILD.gn
  # https://source.chromium.org/chromium/chromium/src/+/refs/tags/150.0.7871.250:build/config/c++/BUILD.gn
  export CC="$PWD/.build/CR_Clang/bin/clang --gcc-toolchain=$VSCODE_CLIENT_SYSROOT_DIR/x86_64-linux-gnu"
  export CXX="$PWD/.build/CR_Clang/bin/clang++ --gcc-toolchain=$VSCODE_CLIENT_SYSROOT_DIR/x86_64-linux-gnu"
  export CXXFLAGS="-nostdinc++ -D__NO_INLINE__ -DSPDLOG_USE_STD_FORMAT -I$PWD/.build/libcxx_headers -isystem$PWD/.build/libcxx_headers/include -isystem$PWD/.build/libcxxabi_headers/include -fPIC -flto=thin -fsplit-lto-unit -D_LIBCPP_ABI_NAMESPACE=Cr -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_EXTENSIVE --sysroot=$VSCODE_CLIENT_SYSROOT_DIR/x86_64-linux-gnu/x86_64-linux-gnu/sysroot"
  export LDFLAGS="-stdlib=libc++ --sysroot=$VSCODE_CLIENT_SYSROOT_DIR/x86_64-linux-gnu/x86_64-linux-gnu/sysroot -fuse-ld=lld -flto=thin -L$PWD/.build/libcxx-objects -lc++abi -L$VSCODE_CLIENT_SYSROOT_DIR/x86_64-linux-gnu/x86_64-linux-gnu/sysroot/usr/lib/x86_64-linux-gnu -L$VSCODE_CLIENT_SYSROOT_DIR/x86_64-linux-gnu/x86_64-linux-gnu/sysroot/lib/x86_64-linux-gnu -Wl,--lto-O0"

  # Set compiler toolchain for remote server
  export VSCODE_REMOTE_CC=$VSCODE_REMOTE_SYSROOT_DIR/x86_64-linux-gnu/bin/x86_64-linux-gnu-gcc
  export VSCODE_REMOTE_CXX=$VSCODE_REMOTE_SYSROOT_DIR/x86_64-linux-gnu/bin/x86_64-linux-gnu-g++
  export VSCODE_REMOTE_CXXFLAGS="--sysroot=$VSCODE_REMOTE_SYSROOT_DIR/x86_64-linux-gnu/x86_64-linux-gnu/sysroot"
  export VSCODE_REMOTE_LDFLAGS="--sysroot=$VSCODE_REMOTE_SYSROOT_DIR/x86_64-linux-gnu/x86_64-linux-gnu/sysroot -L$VSCODE_REMOTE_SYSROOT_DIR/x86_64-linux-gnu/x86_64-linux-gnu/sysroot/usr/lib/x86_64-linux-gnu -L$VSCODE_REMOTE_SYSROOT_DIR/x86_64-linux-gnu/x86_64-linux-gnu/sysroot/lib/x86_64-linux-gnu"
elif [ "$npm_config_arch" == "arm64" ]; then
  # Set compiler toolchain for client native modules
  export CC=$VSCODE_CLIENT_SYSROOT_DIR/aarch64-linux-gnu/bin/aarch64-linux-gnu-gcc
  export CXX=$VSCODE_CLIENT_SYSROOT_DIR/aarch64-linux-gnu/bin/aarch64-linux-gnu-g++
  export CXXFLAGS="--sysroot=$VSCODE_CLIENT_SYSROOT_DIR/aarch64-linux-gnu/aarch64-linux-gnu/sysroot"
  export LDFLAGS="--sysroot=$VSCODE_CLIENT_SYSROOT_DIR/aarch64-linux-gnu/aarch64-linux-gnu/sysroot -L$VSCODE_CLIENT_SYSROOT_DIR/aarch64-linux-gnu/aarch64-linux-gnu/sysroot/usr/lib/aarch64-linux-gnu -L$VSCODE_CLIENT_SYSROOT_DIR/aarch64-linux-gnu/aarch64-linux-gnu/sysroot/lib/aarch64-linux-gnu"

  # Set compiler toolchain for remote server
  export VSCODE_REMOTE_CC=$VSCODE_REMOTE_SYSROOT_DIR/aarch64-linux-gnu/bin/aarch64-linux-gnu-gcc
  export VSCODE_REMOTE_CXX=$VSCODE_REMOTE_SYSROOT_DIR/aarch64-linux-gnu/bin/aarch64-linux-gnu-g++
  export VSCODE_REMOTE_CXXFLAGS="--sysroot=$VSCODE_REMOTE_SYSROOT_DIR/aarch64-linux-gnu/aarch64-linux-gnu/sysroot"
  export VSCODE_REMOTE_LDFLAGS="--sysroot=$VSCODE_REMOTE_SYSROOT_DIR/aarch64-linux-gnu/aarch64-linux-gnu/sysroot -L$VSCODE_REMOTE_SYSROOT_DIR/aarch64-linux-gnu/aarch64-linux-gnu/sysroot/usr/lib/aarch64-linux-gnu -L$VSCODE_REMOTE_SYSROOT_DIR/aarch64-linux-gnu/aarch64-linux-gnu/sysroot/lib/aarch64-linux-gnu"
elif [ "$npm_config_arch" == "arm" ]; then
  # Set compiler toolchain for client native modules
  export CC=$VSCODE_CLIENT_SYSROOT_DIR/arm-rpi-linux-gnueabihf/bin/arm-rpi-linux-gnueabihf-gcc
  export CXX=$VSCODE_CLIENT_SYSROOT_DIR/arm-rpi-linux-gnueabihf/bin/arm-rpi-linux-gnueabihf-g++
  export CXXFLAGS="--sysroot=$VSCODE_CLIENT_SYSROOT_DIR/arm-rpi-linux-gnueabihf/arm-rpi-linux-gnueabihf/sysroot"
  export LDFLAGS="--sysroot=$VSCODE_CLIENT_SYSROOT_DIR/arm-rpi-linux-gnueabihf/arm-rpi-linux-gnueabihf/sysroot -L$VSCODE_CLIENT_SYSROOT_DIR/arm-rpi-linux-gnueabihf/arm-rpi-linux-gnueabihf/sysroot/usr/lib/arm-linux-gnueabihf -L$VSCODE_CLIENT_SYSROOT_DIR/arm-rpi-linux-gnueabihf/arm-rpi-linux-gnueabihf/sysroot/lib/arm-linux-gnueabihf"

  # Set compiler toolchain for remote server
  export VSCODE_REMOTE_CC=$VSCODE_REMOTE_SYSROOT_DIR/arm-rpi-linux-gnueabihf/bin/arm-rpi-linux-gnueabihf-gcc
  export VSCODE_REMOTE_CXX=$VSCODE_REMOTE_SYSROOT_DIR/arm-rpi-linux-gnueabihf/bin/arm-rpi-linux-gnueabihf-g++
  export VSCODE_REMOTE_CXXFLAGS="--sysroot=$VSCODE_REMOTE_SYSROOT_DIR/arm-rpi-linux-gnueabihf/arm-rpi-linux-gnueabihf/sysroot"
  export VSCODE_REMOTE_LDFLAGS="--sysroot=$VSCODE_REMOTE_SYSROOT_DIR/arm-rpi-linux-gnueabihf/arm-rpi-linux-gnueabihf/sysroot -L$VSCODE_REMOTE_SYSROOT_DIR/arm-rpi-linux-gnueabihf/arm-rpi-linux-gnueabihf/sysroot/usr/lib/arm-linux-gnueabihf -L$VSCODE_REMOTE_SYSROOT_DIR/arm-rpi-linux-gnueabihf/arm-rpi-linux-gnueabihf/sysroot/lib/arm-linux-gnueabihf"
elif [ "$npm_config_arch" == "loong64" ]; then
  # Build for the upstream LoongArch ("new-world") LP64D ABI. A sysroot is
  # supplied by the port owner because Microsoft does not publish a Loong64
  # VS Code sysroot.
  if [ -z "${VSCODE_LOONG64_SYSROOT_DIR:-}" ] || [ ! -d "$VSCODE_LOONG64_SYSROOT_DIR" ]; then
    echo "VSCODE_LOONG64_SYSROOT_DIR must point to a new-world LoongArch sysroot" >&2
    exit 1
  fi
  if [ -n "${VSCODE_LOONG64_CC:-}" ]; then
    export VSCODE_CLIENT_CC="$VSCODE_LOONG64_CC"
  elif [ -x "$VSCODE_LOONG64_SYSROOT_DIR/bin/loongarch64-linux-gnu-gcc" ]; then
    export VSCODE_CLIENT_CC="$VSCODE_LOONG64_SYSROOT_DIR/bin/loongarch64-linux-gnu-gcc"
  elif command -v loongarch64-linux-gnu-gcc >/dev/null 2>&1; then
    export VSCODE_CLIENT_CC="$(command -v loongarch64-linux-gnu-gcc)"
  else
    echo "No LoongArch GCC found; set VSCODE_LOONG64_CC or install loongarch64-linux-gnu-gcc" >&2
    exit 1
  fi
  if [ -n "${VSCODE_LOONG64_CXX:-}" ]; then
    export VSCODE_CLIENT_CXX="$VSCODE_LOONG64_CXX"
  elif [ -x "$VSCODE_LOONG64_SYSROOT_DIR/bin/loongarch64-linux-gnu-g++" ]; then
    export VSCODE_CLIENT_CXX="$VSCODE_LOONG64_SYSROOT_DIR/bin/loongarch64-linux-gnu-g++"
  elif command -v loongarch64-linux-gnu-g++ >/dev/null 2>&1; then
    export VSCODE_CLIENT_CXX="$(command -v loongarch64-linux-gnu-g++)"
  else
    echo "No LoongArch G++ found; set VSCODE_LOONG64_CXX or install loongarch64-linux-gnu-g++" >&2
    exit 1
  fi
  export VSCODE_LOONG64_ABI_FLAGS="${VSCODE_LOONG64_ABI_FLAGS:--march=loongarch64 -mabi=lp64d -mlsx}"
  export CC="$VSCODE_CLIENT_CC"
  export CXX="$VSCODE_CLIENT_CXX"
  export CFLAGS="$VSCODE_LOONG64_ABI_FLAGS --sysroot=$VSCODE_LOONG64_SYSROOT_DIR ${CFLAGS:-}"
  export CXXFLAGS="$VSCODE_LOONG64_ABI_FLAGS --sysroot=$VSCODE_LOONG64_SYSROOT_DIR ${CXXFLAGS:-}"
  export LDFLAGS="$VSCODE_LOONG64_ABI_FLAGS --sysroot=$VSCODE_LOONG64_SYSROOT_DIR -Wl,--dynamic-linker=/lib64/ld-linux-loongarch-lp64d.so.1 -L$VSCODE_LOONG64_SYSROOT_DIR/usr/lib/loongarch64-linux-gnu -L$VSCODE_LOONG64_SYSROOT_DIR/lib/loongarch64-linux-gnu ${LDFLAGS:-}"
  export VSCODE_REMOTE_CC="$VSCODE_CLIENT_CC"
  export VSCODE_REMOTE_CXX="$VSCODE_CLIENT_CXX"
  export VSCODE_REMOTE_CXXFLAGS="$VSCODE_LOONG64_ABI_FLAGS --sysroot=$VSCODE_LOONG64_SYSROOT_DIR"
  export VSCODE_REMOTE_LDFLAGS="$LDFLAGS"
fi
