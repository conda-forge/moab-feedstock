#!/bin/bash
set -e
set -x

export CONFIGURE_ARGS="--with-eigen3=${PREFIX}/include/eigen3 ${CONFIGURE_ARGS}"
export CONFIGURE_ARGS="-DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX}"

if [[ -n "$mpi" && "$mpi" != "nompi" ]]; then
  export CONFIGURE_ARGS="-DCMAKE_C_COMPILER=mpicc -DCMAKE_CXX_COMPILER=mpic++ -DENABLE_MPI=ON -DENABLE_ZOLTAN=ON"
fi

if [[ -n "$tempest" && "$tempest" != "notempest" ]]; then
  export CONFIGURE_ARGS="-DENABLE_TEMPESTREMAP=ON -DENABLE_NETCDF=ON ${CONFIGURE_ARGS}"
fi

mkdir bld
cd bld
cmake .. -DCMAKE_INSTALL_PREFIX=${PREFIX} \
         -DENABLE_HDF5=ON \
         -DHDF5_ROOT=${PREFIX} \
         -DENABLE_METIS=ON \
         -DBUILD_SHARED_LIBS=ON \
         -DENABLE_PYMOAB=ON \
         -DENABLE_BLASLAPACK=OFF \
         -DENABLE_FORTRAN=OFF \
         ${CONFIGURE_ARGS}

make -j "${CPU_COUNT}"

make check \
  || { cat itaps/imesh/test-suite.log; exit 1; }

make install
