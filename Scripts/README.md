# OpenLane2 Tests
## Installation
### Install NIX: 
Run the command to install NIX.
```
bash <(curl -L https://nixos.org/nix/install)
```
### Clone OpenLane2
```
git submodule update --init --recursive
```
### Install and Run OpenLane2
```
cd openlane2
nix-shell
```
The first time might take around 10 minutes while binaries are pulled from the cache.

To run openlane, `cd openlane2`, go into NIX shell (`nix-shell`), navigate to any other directory, and run `openlane`.
### Download PDKs
This assumes we are using sky130.
```
volare enable --pdk sky130 <commit>  --pdk-root <pdk_download_dir>
```
To find appropriate `<commit>`, run:
```
volare ls-remote --pdk sky130
```
- I am using commit `0fe599b2afb6708d281543108caf8310912f54af`

The PDK should be stored under `~/.volare` if we do not include the `--pdf-root` command. However, that was used, change the PDK_ROOT parameter under notebook.py
### Create ENV
Create a `.env` file inside `Scripts` directory. Add `VOLARE_FOLDER="<[pdk_download_dir]>"`. 

Example: `VOLARE_FOLDER="/home/ethanhuang03/.volare"`
## Files 
1. `notebook.py` is a reproduction of [this notebook](https://colab.research.google.com/github/efabless/openlane2/blob/main/notebook.ipynb).
2. `spm.v` is the Verilog file provided from [this notebook](https://colab.research.google.com/github/efabless/openlane2/blob/main/notebook.ipynb).