#!/usr/bin/env bash
set -euo pipefail

test -f /source.tar && test -d /work && test -d /output
test ! -e /work/core && test ! -e /work/retroarch

restore_host_ownership() {
  chown -R "${RETROM_HOST_UID:?}:${RETROM_HOST_GID:?}" /work /output
}
trap restore_host_ownership EXIT

mkdir -p /work/core /work/retroarch
tar -C /work/core -xf /source.tar

# The browser frontend must be built against the same pinned RetroArch port
# used by the other Retrom EmulatorJS cores.
git -C /work/retroarch init -q
git -C /work/retroarch remote add origin https://github.com/EmulatorJS/RetroArch.git
git -C /work/retroarch fetch -q --depth 1 origin 6dd4353937ef48b6ec0bfbdbb15d1c5992d86927
git -C /work/retroarch checkout -q --detach FETCH_HEAD
install -m 0644 /work/retroarch/COPYING /output/retroarch-COPYING

emmake make -C /work/core platform=emscripten -j4
install -m 0644 /work/core/supermodel_libretro_emscripten.a /work/retroarch/libretro_emscripten.a

emmake make -C /work/retroarch -f Makefile.emulatorjs \
  HAVE_CHD=1 HAVE_THREADS=0 PTHREAD_POOL_SIZE=0 ASYNC=1 HAVE_AL=1 HAVE_OPENGLES3=1 \
  STACK_SIZE=8388608 INITIAL_HEAP=268435456 TARGET=supermodel_libretro.js -j4

install -m 0644 /work/retroarch/supermodel_libretro.js /output/
install -m 0644 /work/retroarch/supermodel_libretro.wasm /output/
