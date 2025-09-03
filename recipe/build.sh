#!/bin/bash
set -e
set -x

export CONFIGURE_ARGS="--with-eigen3=${PREFIX}/include/eigen3 ${CONFIGURE_ARGS}"

if [[ -n "$mpi" && "$mpi" != "nompi" ]]; then
  if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
    # In cross builds, do NOT use target mpicc/mpic++ (can't execute on build machine).
    # Use the cross C/C++ compilers provided by conda-forge toolchain and supply MPI flags.
    export CONFIGURE_ARGS="--with-mpi=${PREFIX} --with-zoltan=${PREFIX} ${CONFIGURE_ARGS}"
    # Help Autoconf-based MPI checks without executing target wrappers.
    # Point MPICC/MPICXX at the active cross compilers so any macro that
    # prefers these variables won't try to execute ${PREFIX}/bin/mpicc.
    export MPICC="${CC}"
    export MPICXX="${CXX}"
    # Help discovery of MPI headers/libs without executing target wrappers.
    export MPI_CFLAGS="-I${PREFIX}/include ${MPI_CFLAGS}"
    export MPI_LIBS="-L${PREFIX}/lib -lmpi ${MPI_LIBS}"
    # Ensure -lmpi is available when linking MPI test programs.
    export LIBS="${LIBS} -lmpi"
    # Make sure pkg-config can find mpi.pc (if provided by the MPI package).
    export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
  else
    export CONFIGURE_ARGS="CC=mpicc CXX=mpic++ --with-mpi=${PREFIX} --with-zoltan=${PREFIX} ${CONFIGURE_ARGS}"
  fi
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
  --enable-pymoab \
  --disable-fortran \
  || { cat config.log; exit 1; }

make -j "${CPU_COUNT}"

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR}" != "" ]]; then
make check \
  || { cat test/test-suite.log; exit 1; }
fi

make install
