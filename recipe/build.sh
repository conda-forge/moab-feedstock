#!/bin/bash
set -e
set -x

export CONFIGURE_ARGS="--with-eigen3=${PREFIX}/include/eigen3 ${CONFIGURE_ARGS}"

if [[ -n "$mpi" && "$mpi" != "nompi" ]]; then
  export CONFIGURE_ARGS="CC=mpicc CXX=mpic++ --with-mpi=${PREFIX} ${CONFIGURE_ARGS}"
fi

if [[ -n "$tempest" && "$tempest" != "notempest" ]]; then
  export CONFIGURE_ARGS="--with-tempestremap=${PREFIX} --with-netcdf=${PREFIX} --with-netcdf-cxx=${PREFIX} ${CONFIGURE_ARGS}"
fi

autoreconf -fi
./configure --prefix="${PREFIX}" \
  ${CONFIGURE_ARGS} \
  --with-hdf5="${PREFIX}" \
  --with-metis="${PREFIX}" \
  --enable-shared \
  --enable-tools \
  --enable-pymoab \
  --disable-fortran \
  || { cat config.log; exit 1; }
make -j "${CPU_COUNT}"
if [ "$(uname)" == "Linux" ]; then
  # tests fail to link on mac because HDF5 rpaths haven't been rewritten yet.
  make check \
    || { cat itaps/imesh/test-suite.log; exit 1; }
fi

make install
