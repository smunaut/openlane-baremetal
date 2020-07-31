#!/usr/bin/env bash

set -e

# Configuration
# -------------

OPENLANE_WORKSPACE="${OPENLANE_WORKSPACE:-${HOME}/sky130/openlane_workspace}"

PREFIX="${OPENLANE_WORKSPACE}/_root"
BUILD_PATH="${OPENLANE_WORKSPACE}/_build"
PATCH_PATH="$(dirname `which $0`)/patches"

TAG=${TAG:-$(date "+build_%Y%m%d_%H%M%S")}

nproc=${nproc:-12}

PYVER="3.7"

if [ ! -d "${PATCH_PATH}" ]; then
	echo "[!] Can't find path directory ( ${PATCH_PATH} )"
	exit 1
fi

echo "[+] Installing in ${OPENLANE_WORKSPACE}"


# List of all tools
# -----------------
# (and matching sources)

TOOLS="${TOOLS:-cudd replace ioplacer opendp route route_14 fastroute opensta yosys magic resizer addspacers openroad padring netgen vlogtoverilog}"

addspacers_GIT_SRC=https://github.com/RTimothyEdwards/qflow
addspacers_GIT_HASH=ad92e709bcd6c8604816a6c98cef2e35a841de85

cudd_GIT_SRC=https://github.com/ivmai/cudd.git
cudd_GIT_HASH=f54f533303640afd5dbe47a05ebeabb3066f2a25

fastroute_GIT_SRC=https://github.com/The-OpenROAD-Project/FastRoute
fastroute_GIT_HASH=8a71eea8216c08a506219330b738720f9b4a43f0

ioplacer_GIT_SRC=https://github.com/The-OpenROAD-Project/ioPlacer
ioplacer_GIT_HASH=a7e0b0b4200c6b34a6c93bbafdf72027284e588a

opendp_GIT_SRC=https://github.com/kareefardi/OpenDP
opendp_GIT_HASH=master

openroad_GIT_SRC=https://github.com/The-OpenROAD-Project/OpenROAD
openroad_GIT_HASH=d6e0844670b4f8c8cd654258853eb868945c7665

opensta_GIT_SRC=https://github.com/The-OpenROAD-Project/OpenSTA
opensta_GIT_HASH=e7d8689f70497eda1ad2686ecfcd628ffccb3a2e

padring_GIT_SRC=https://github.com/YosysHQ/padring
padring_GIT_HASH=master

replace_GIT_SRC=https://github.com/The-OpenROAD-Project/RePlAce
replace_GIT_HASH=950b5df4ea6a70fcfb1d496e85cfa63bdd172499

resizer_GIT_SRC=https://github.com/The-OpenROAD-Project/Resizer.git
resizer_GIT_HASH=fdb54f9eaf54e772a6af79181cf71a6d5816807e

route_GIT_SRC=https://github.com/agorararmard/TritonRoute
route_GIT_HASH=d7f9a061a6e209225b663f69e5013daa33191bae

route_14_GIT_SRC=https://github.com/The-OpenROAD-Project/TritonRoute.git
route_14_GIT_HASH=1570d785ff1cb28b998e5d2c8c8d24ec76e32dbf

magic_GIT_SRC=https://github.com/RTimothyEdwards/magic.git
magic_GIT_HASH=master

netgen_GIT_SRC=git://opencircuitdesign.com/netgen
netgen_GIT_HASH=8e215d3b66acd6a6fa937cc1d1f594cdb75f3d62

tapcell_GIT_SRC=https://github.com/The-OpenROAD-Project/tapcell.git
tapcell_GIT_HASH=40b174ecdcbf67a6adebda0eb86e22db22e21e77

vlogtoverilog_GIT_SRC=https://github.com/RTimothyEdwards/qflow
vlogtoverilog_GIT_HASH=a550469b63e910ede6e3022e2886bca96462c540

yosys_GIT_SRC=https://github.com/YosysHQ/yosys
yosys_GIT_HASH=347dd01c2f7dff6e8222c5f9d360f84a17c937b5


# Helpers
# -------

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

function git_is_in_local() {
	local branch=${1}
	local existed_in_local=$(git branch --list ${branch})

	if [ "${existed_in_local}" == "" ]; then
		echo 0
	else
		echo 1
	fi
}

function checkout() {
	local n;

	# Fetch tool infos
	local tool="$1"

	n="${tool}_PATH"
	local T_PATH="${!n}"

	n="${tool}_GIT_SRC"
	local T_GIT_SRC="${!n}"

	n="${tool}_GIT_HASH"
	local T_GIT_HASH="${!n}"

	# If path is empty, use git
	if [ "${T_PATH}" == "" ]; then
		# Set path
		T_PATH="${BUILD_PATH}/${tool}"

		# Go to parent
		pushd "${BUILD_PATH}"

		# If it doesn't exist, new checkout
		if [ ! -d "${tool}" ]; then
			git clone --recursive "${T_GIT_SRC}" "${tool}"
			pushd "${tool}"
		else
			pushd "${tool}"
			git remote update -p
		fi

		# Checkout branch
		if [ "${T_GIT_HASH}" == "asis" ]; then
			# Don't touch ...
			true;
		else
			if [ "${T_GIT_HASH}" == "master" ]; then
				T_GIT_HASH="origin/master"
			fi

			local has_tag=$(git_is_in_local "${TAG}")

			if [ "${has_tag}" == "0" ]; then
				# Tag doesn't exist, do new checkout
				echo git checkout -b "${TAG}" "${T_GIT_HASH}"
				git checkout -b "${TAG}" "${T_GIT_HASH}"
			else
				# Tag exists, switch to it
				echo git checkout "${TAG}"
				git checkout "${TAG}"

				# Update / set-it to target commit
				if [ "$(git rev-parse ${T_GIT_HASH})" != "$(git rev-parse HEAD)" ]; then
					git reset --hard ${T_GIT_HASH}
				fi
			fi

			git submodule update
		fi

		# Done
		popd
		popd
	fi

	# Set path variable
	printf -v "${tool}_PATH" '%s' "${T_PATH}"
}

function build() {
	# Fetch tool infos
	local tool="$1"
	local n="${tool}_PATH"
	local T_PATH="${!n}"

	# Go to directory
	pushd "${T_PATH}"

	# Apply patch if any
	if [ -e "${PATCH_PATH}/${tool}.diff" ]; then
		patch -p1 --forward -r - < "${PATCH_PATH}/${tool}.diff" || true
	fi
	echo "${PATCH_PATH}/${tool}.diff" 

	# Call build function
	build_${tool}

	# Reverse patch
	if [ -e "${PATCH_PATH}/${tool}.diff" ]; then
		patch -p1 --reverse -r - < "${PATCH_PATH}/${tool}.diff" || true
	fi

	# Done
	popd
}

function cmake_build() {
	mkdir -p _build
	pushd _build
	cmake .. -DCMAKE_INSTALL_PREFIX="${PREFIX}" "$@"
	make -j ${nproc}
	popd
}


# Build functions
# ---------------

function build_cudd() {
	autoreconf -fi
	./configure --prefix="${PREFIX}" 
	make -j ${nproc}
	make install
}

function build_replace() {
	cmake_build

	cp _build/replace "${PREFIX}/bin"
}

function build_ioplacer() {
	cmake_build

	cp _build/ioPlacer "${PREFIX}/bin"
	cp scripts/replace_ioplace_loop.sh "${PREFIX}/bin"
}

function build_opendp() {
	cmake_build

	cp _build/opendp "${PREFIX}/bin"
}

function build_route() {
	cmake_build

	cp _build/TritonRoute "${PREFIX}/bin"
}

function build_route_14() {
	cmake_build

	cp _build/TritonRoute "${PREFIX}/bin/TritonRoute14"
}

function build_fastroute() {
	cmake_build

	cp _build/FastRoute "${PREFIX}/bin"
}

function build_opensta() {
	cmake_build -DCUDD="${PREFIX}"

	cp app/sta "${PREFIX}/bin"
}

function build_yosys() {
	make PREFIX="${PREFIX}" config-gcc
	make PREFIX="${PREFIX}" -j ${nproc}
	make PREFIX="${PREFIX}" install
}

function build_tapcell() {
	# Pre Build SWIG 4.0
	if [ ! -d "_swig" ]; then
		mkdir -p "_swig"
		pushd "_swig"
		wget http://prdownloads.sourceforge.net/swig/swig-4.0.0.tar.gz
		tar -xzvf swig-4.0.0.tar.gz 
		pushd swig-4.0.0
		./configure --prefix="$(pwd)/../_root"
		make -j ${nproc}
		make install
		popd
		popd
	fi

	# Build and install
	make release SWIG="$(pwd)/_swig/_root/bin/swig"

	cp bin/tapcell "${PREFIX}/bin"
}

function build_magic() {
	./configure --prefix="${PREFIX}"
	make -j ${nproc}
	make install
}

function build_resizer() {
	cmake_build -DCUDD="${PREFIX}"

	cp _build/resizer "${PREFIX}/bin"
	cp _build/verilog2def "${PREFIX}/bin"
}

function build_addspacers() {
	./configure --prefix="${PREFIX}"
	pushd src
	make -j ${nproc} addspacers
	popd

	cp src/addspacers "${PREFIX}/bin"
}

function build_openroad() {
	# Main build
	cmake_build
	cp _build/src/openroad "${PREFIX}/bin"

	# OpenDB Python bindings
	pushd "src/OpenDB"
	cmake_build
	cp _build/src/swig/python/_opendbpy.so "${PREFIX}/lib/python${PYVER}/site-packages/"
	cp _build/src/swig/python/opendbpy.py  "${PREFIX}/lib/python${PYVER}/site-packages/"
	popd
}

function build_padring() {
	cmake_build

	cp _build/padring "${PREFIX}/bin"
}

function build_netgen() {
	./configure --prefix="${PREFIX}"
	make -j ${nproc}
	make install
}

function build_vlogtoverilog() {
	./configure --prefix="${PREFIX}"
	pushd src
	make -j ${nproc} vlog2Verilog
	popd

	cp src/vlog2Verilog "${PREFIX}/bin"
}


# Pre-setup
# ---------

# Create root
if [ ! -d "${PREFIX}" ]; then
	mkdir -p "${PREFIX}"
	mkdir -p "${PREFIX}/bin"
	mkdir -p "${PREFIX}/lib"
	mkdir -p "${PREFIX}/lib/python${PYVER}/site-packages/"
fi

if [ ! -L "${PREFIX}/lib64" ]; then
	ln -s lib "${PREFIX}/lib64"
fi

# Create environment file and load it
if [ ! -f "${OPENLANE_WORKSPACE}/env.sh" ]; then
	cat > "${OPENLANE_WORKSPACE}/env.sh" << EOF
PREFIX="${PREFIX}"

# Base stuff
export PATH="\${PREFIX}/bin:\${PATH}"
export LD_LIBRARY_PATH="\${PREFIX}/lib:\${LD_LIBRARY_PATH}"
export PKG_CONFIG_PATH="\${PREFIX}/lib/pkgconfig:\${PKG_CONFIG_PATH}"
export PYTHONPATH="\${PREFIX}/lib/python${PYVER}/site-packages/:\${PYTHONPATH}"
export CMAKE_PREFIX_PATH="\${PREFIX}"

# OpenLANE
export OPENLANE_ROOT="${OPENLANE_WORKSPACE}/openlane"
export PDK_ROOT="${OPENLANE_WORKSPACE}/pdks"
EOF
fi

source "${OPENLANE_WORKSPACE}/env.sh"

# Create build dir
if [ ! -d "${BUILD_PATH}" ]; then
	mkdir -p "${BUILD_PATH}"
fi


# Build all tools
# ---------------

for tool in ${TOOLS}; do
	echo "[+] Checking out ${tool}"
	checkout ${tool}

	echo "[+] Building ${tool}"
	build ${tool}
done
