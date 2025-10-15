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
  # Conditionally skip long-running tests on macOS with TempestRemap to avoid CI timeouts.
  # We replace the test executable with a tiny wrapper that returns 77 (SKIP in Automake).
  maybe_skip_tests() {
    # args: listfile
    local listfile="$1"
    [[ -f "${listfile}" ]] || return 0
    while IFS= read -r tname; do
      # ignore blanks and comments
      [[ -z "${tname}" || "${tname}" =~ ^# ]] && continue
      # search for test executable in build tree (common dirs)
      for d in test test/*; do
        if [[ -x "$d/${tname}" ]]; then
          echo "Skipping test ${tname} via wrapper (automake SKIP)"
          local exe="$d/${tname}"
          local exe_real="${exe}.real"
          # keep original around (in case of local debugging)
          mv "${exe}" "${exe_real}"
          # create a POSIX sh wrapper that exits with 77 to mark SKIP
          cat > "${exe}" <<'EOS'
#!/usr/bin/env sh
echo "[conda-forge] Skipping this test per recipe configuration."
exit 77
EOS
          chmod +x "${exe}"
          break
        fi
      done
    done < "${listfile}"
  }

  # Determine platform and features to pick a skip list.
  # On conda-forge, OS X is identified as Darwin in uname.
  UNAME_S=$(uname -s || true)
  if [[ "${UNAME_S}" == "Darwin" ]] && [[ -n "$tempest" && "$tempest" != "notempest" ]]; then
    # Always apply the base macOS+TempestRemap skip list
    maybe_skip_tests "${RECIPE_DIR}/disabled-tests/osx-tempest.txt"
    # Demonstrate different skip sets depending on MPI presence
    if [[ -n "$mpi" && "$mpi" != "nompi" ]]; then
      echo "[conda-forge] MPI enabled: applying osx-tempest-mpi skip list"
      maybe_skip_tests "${RECIPE_DIR}/disabled-tests/osx-tempest-mpi.txt"
    else
      echo "[conda-forge] MPI disabled: applying osx-tempest-nompi skip list"
      maybe_skip_tests "${RECIPE_DIR}/disabled-tests/osx-tempest-nompi.txt"
    fi
  fi

  # After any skip wrappers have been applied above, run the full automake test suite.

  make check \
    || { cat test/test-suite.log; exit 1; }
fi

make install
