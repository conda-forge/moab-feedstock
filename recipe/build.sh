#!/bin/bash
set -e
set -x

if [[ ! -z "$mpi" && "$mpi" != "nompi" ]]; then
  export CONFIGURE_ARGS="--with-mpi=${PREFIX} ${CONFIGURE_ARGS}"
fi

autoreconf -fi
./configure --prefix="${PREFIX}" \
  ${CONFIGURE_ARGS} \
  --with-hdf5="${PREFIX}" \
  --enable-shared \
  --enable-tools \
  --enable-pymoab \
  || { cat config.log; exit 1; }
make -j "${CPU_COUNT}"
if [ "$(uname)" == "Linux" ]; then
  # tests fail to link on mac because HDF5 rpaths haven't been rewritten yet.
  make check \
    || { cat itaps/imesh/test-suite.log; exit 1; }
fi
make install
