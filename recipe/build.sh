#!/bin/bash
set -e
set -x

export CONFIGURE_ARGS="--with-eigen3=${PREFIX}/include/eigen3 ${CONFIGURE_ARGS}"

if [[ -n "$mpi" && "$mpi" != "nompi" ]]; then
  export CONFIGURE_ARGS="CC=mpicc CXX=mpic++ FC=mpif90 F77=mpif77 --with-mpi=${PREFIX} --with-zoltan=${PREFIX} ${CONFIGURE_ARGS}"
fi

if [[ -n "$tempest" && "$tempest" != "notempest" ]]; then
  export CONFIGURE_ARGS="--with-tempestremap=${PREFIX} --with-netcdf=${PREFIX} ${CONFIGURE_ARGS}"
fi

autoreconf -fi
./configure --prefix="${PREFIX}" \
  ${CONFIGURE_ARGS} \
  --with-hdf5="${PREFIX}" \
  --with-metis="${PREFIX}" \
  --enable-shared \
  --enable-tools \
  || { cat config.log; exit 1; }

make -j "${CPU_COUNT}"

make check \
  || { cat test/test-suite.log; exit 1; }

make install
