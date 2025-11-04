#!/bin/bash
set -e
set -x

export CONFIGURE_ARGS="--with-eigen3=${PREFIX}/include/eigen3 ${CONFIGURE_ARGS}"

if [[ -n "$mpi" && "$mpi" != "nompi" ]]; then
  export CONFIGURE_ARGS="CC=mpicc CXX=mpic++ --with-mpi=${PREFIX} --with-zoltan="${PREFIX}" ${CONFIGURE_ARGS}"
fi

if [[ -n "$tempest" && "$tempest" != "notempest" ]]; then
  export CONFIGURE_ARGS="--with-tempestremap=${PREFIX} --with-netcdf=${PREFIX} ${CONFIGURE_ARGS}"
else
  # no blas/lapack support without tempestremap so we don't need fortran support
  export CONFIGURE_ARGS="--disable-fortran ${CONFIGURE_ARGS}"
fi

autoreconf -fi
./configure --prefix="${PREFIX}" \
  ${CONFIGURE_ARGS} \
  --with-hdf5="${PREFIX}" \
  --with-metis="${PREFIX}" \
  --enable-shared \
  --enable-tools \
  --enable-pymoab \
  || { cat config.log; exit 1; }

make -j "${CPU_COUNT}"

make check \
  || { cat test/test-suite.log; exit 1; }

make install
