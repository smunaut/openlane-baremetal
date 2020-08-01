# TL;DR

OpenLANE is made up of three main components :
* A collection of tools used during the flow. This is what this build script handles.
* The PDK itself (i.e. data files describing the process).
* OpenLANE itself which is the script making use of the above two.

## Install the tools

```bash
sudo apt install tcl-dev tk-dev csh libjpeg-dev tcllib

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
git checkout 4e5e318e0cc578090e1ae7d6f2cb1ec99f363120
git submodule update --init libraries/sky130_fd_sc_hd/latest
make sky130_fd_sc_hd

cd $PDK_ROOT
git clone https://github.com/efabless/open_pdks.git --branch rc2
cd open_pdks
make
make install-local
```

## Install OpenLANE itsef

```bash
cd ${HOME}/sky130/openlane_workspace/
git clone https://github.com/efabless/openlane.git --branch rc2
```

## Using OpenLANE

```bash
source ${HOME}/sky130/openlane_workspace/env.sh
cd ${HOME}/sky130/openlane_workspace/openlane
./flow.tcl -design spm
```
