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
  export CONFIGURE_ARGS="--with-tempestremap=${PREFIX} --with-netcdf=${PREFIX} --enable-mbtempest ${CONFIGURE_ARGS}"
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
  # If TempestRemap is enabled, run only a curated subset of tests to avoid timeouts.
  if [[ -n "$tempest" && "$tempest" != "notempest" ]]; then
    echo "[conda-forge] TempestRemap enabled: running a selected subset of tests."

    # Helper: check if a test target is defined in the given directory's Makefile
    is_test_defined() {
      local dir="$1"; shift
      local name="$1"; shift
      [[ -f "${dir}/Makefile" ]] && grep -q "${name}_SOURCES" "${dir}/Makefile"
    }

    # Tests to run for both MPI and no-MPI builds (found under test/)
    COMMON_SERIAL_TESTS=(
      imoab_remapping
      imoab_test
      test_remapping
    )

    # Additional tests for MPI builds (found under test/parallel/)
    COMMON_PARALLEL_TESTS=(
      imoab_coupler
      imoab_coupler_bilin
      imoab_coupler_fortran
      imoab_coupler_twohop
      imoab_read_map
    )

    # Filter to only those tests that are actually defined for this configuration
    SERIAL_ENABLED=()
    for t in "${COMMON_SERIAL_TESTS[@]}"; do
      if is_test_defined "test" "${t}"; then
        SERIAL_ENABLED+=("${t}")
      fi
    done

    PARALLEL_ENABLED=()
    if [[ -n "$mpi" && "$mpi" != "nompi" ]]; then
      for t in "${COMMON_PARALLEL_TESTS[@]}"; do
        # Skip Fortran-only test when Fortran is disabled in this recipe
        if [[ "${t}" == "imoab_coupler_fortran" ]]; then
          continue
        fi
        if is_test_defined "test/parallel" "${t}"; then
          PARALLEL_ENABLED+=("${t}")
        fi
      done
    fi

    # Run only the selected serial tests
    if [[ ${#SERIAL_ENABLED[@]} -gt 0 ]]; then
      echo "[conda-forge] Running serial tests: ${SERIAL_ENABLED[*]}"
      make -C test check TESTS="${SERIAL_ENABLED[*]}" \
        || { [[ -f test/test-suite.log ]] && cat test/test-suite.log; exit 1; }
    else
      echo "[conda-forge] No selected serial tests were built; skipping test/"
    fi

    # Run only the selected parallel tests when MPI is enabled
    if [[ ${#PARALLEL_ENABLED[@]} -gt 0 ]]; then
      echo "[conda-forge] Running parallel tests: ${PARALLEL_ENABLED[*]}"
      make -C test/parallel check TESTS="${PARALLEL_ENABLED[*]}" \
        || { [[ -f test/parallel/test-suite.log ]] && cat test/parallel/test-suite.log; exit 1; }
    else
      if [[ -n "$mpi" && "$mpi" != "nompi" ]]; then
        echo "[conda-forge] No selected parallel tests were built; skipping test/parallel/"
      else
        echo "[conda-forge] MPI disabled: skipping parallel test subset."
      fi
    fi
  else
    # TempestRemap not enabled: run the full suite
    make check \
      || { cat test/test-suite.log; exit 1; }
  fi
fi

make install
