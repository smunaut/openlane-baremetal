# TL;DR

OpenLANE is made up of three main components :
* A collection of tools used during the flow. This is what this build script handles.
* The PDK itself (i.e. data files describing the process).
* OpenLANE itself which is the script making use of the above two.

## Install the tools

```bash
sudo apt install tcl-dev tk-dev csh libjpeg-dev tcllib python3-pandas

mkdir -p ${HOME}/sky130
cd ${HOME}/sky130

git clone https://github.com/smunaut/openlane-baremetal.git

cd openlane-baremetal
./openlane_build.sh

source ${HOME}/sky130/openlane-workspace/env.sh
```

### Build script configurations

Some environment variables can be defined to override defaults during
the build.

| Variable             | Description
|----------------------|------------------------------------------------------
| `OPENLANE_WORKSPACE` | Location of the workspace where the `_root` and `_build` will be placed (Default: `${HOME}/sky130`
| `nproc`              | Number of threads to use during build (Default: `12`)
| `TAG`                | Name of the local git branch used for build (Default: `build_%Y%m%d_%H%M%S`)
| `TOOLS`              | List of tools to build (Default: build all)

## Install the PDKs

```bash
mkdir -p ${HOME}/sky130/openlane_workspace/pdks
export PDK_ROOT=${HOME}/sky130/openlane_workspace/pdks

cd $PDK_ROOT
git clone https://github.com/google/skywater-pdk.git
cd skywater-pdk
git submodule update --init libraries/sky130_fd_sc_hd/latest
make sky130_fd_sc_hd

cd $PDK_ROOT
git clone https://github.com/RTimothyEdwards/open_pdks.git
cd open_pdks
./configure --with-sky130-source="${PDK_ROOT}/skywater-pdk/libraries" --with-sky130-local-path="${PDK_ROOT}"
cd sky130
make
make install-local
```

## Install OpenLANE itsef

```bash
cd ${HOME}/sky130/openlane_workspace/
git clone https://github.com/efabless/openlane.git --branch develop
```

## Using OpenLANE

```bash
source ${HOME}/sky130/openlane_workspace/env.sh
cd ${HOME}/sky130/openlane_workspace/openlane
./flow.tcl -design spm
```
