#!/bin/bash
set -e
set -x

if [[ -n "$mpi" && "$mpi" != "nompi" ]]; then
  export CONFIGURE_ARGS="CC=mpicc CXX=mpic++ F77=mpif77 FC=mpif90 F90=mpif90 --with-mpi=${PREFIX} ${CONFIGURE_ARGS}"
fi

if [[ -n "$tempest" && "$tempest" != "notempest" ]]; then
  export CONFIGURE_ARGS="--with-tempestremap=${PREFIX} --with-eigen3=${PREFIX}/include/eigen3 --with-netcdf=${PREFIX} --with-netcdf-cxx=${PREFIX} ${CONFIGURE_ARGS}"
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
