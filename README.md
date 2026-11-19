# PUMAS_interface_215

## Purpose

Patches that let the CAM6 atmosphere of CESM 2.1.5 (CAM tag `cam_cesm2_1_rel_60`)
run the current PUMAS cloud microphysics (`micro_pumas_v1`, ESCOMP/PUMAS) as
`micro_mg_version = 3`. PUMAS itself is used unmodified, unless the optional
PUMAS patch set in `patches_pumas/` is applied (see Usage).

Comments in the patches refer to "oPUMAS", the name of the author's
development fork of PUMAS in which this interface was written.

Model changes built on top of this interface, such as the droplet freezing
limiter, live in
[pumas_limiter_update](https://github.com/diegovillanueva/pumas_limiter_update).

## Requirements

- A CESM 2.1.5 installation ported to your machine (`release-cesm2.1.5`), with its standard input data.
- A clone of ESCOMP/PUMAS at the commit pinned in `versions.env`.
- Fortran and C compilers and MPI supported by CESM 2.1.5, and git.

## Contents

| Path | Purpose |
|---|---|
| `patches/micro_mg_cam.F90.patch` | Adds `case (3)` (PUMAS) to readnl, init, get_cols and tend_pack, and reads the namelist group `micro_pumas_nl`. |
| `patches/wv_sat_methods.F90.patch` | Adds `wv_sat_qsat_water_vect` and `wv_sat_qsat_ice_vect`, wrappers around the elemental rel_60 routines that PUMAS calls. |
| `patches/check_energy.F90.patch` | Counts graupel (`GRAUQM`) in the ice water budget and excludes it from the dry-mass fixer. |
| `patches/namelist_definition.xml.patch` | Defines the `micro_pumas_nl` group and the value 3 for `micro_mg_version`. |
| `patches_pumas/*.patch` | Optional changes to PUMAS (against the pinned PUMAS commit): new module `micro_pumas_sppe.F90` with process controls (ice-number cap, deposition nucleation in mixed-phase clouds, detrainment ramp, contact freezing, Hallett-Mossop, rain freezing, autoconversion, riming and Bergeron factors), and the hooks in `micro_pumas_v1.F90` and `micro_pumas_utils.F90`. All defaults reproduce upstream PUMAS. |
| `namelists/user_nl_cam.pumas` | Minimal `user_nl_cam` that selects PUMAS. |
| `namelists/user_nl_cam.pumas_graupel` | Same, with prognostic graupel. |
| `scripts/apply_interface.sh` | Checks the pinned commits, applies the patches to CAM, and optionally copies the PUMAS sources into a case. |
| `versions.env` | Commit pins for CESM, CAM and PUMAS. |
| `LICENSE`, `NOTICE` | BSD 3-Clause License; terms of the modified CESM2 code and of PUMAS. |
| `CITATION.cff`, `.zenodo.json` | Citation and archive metadata. |
| `SHA256SUMS` | Checksums of all tracked files (`sha256sum -c SHA256SUMS`). |

## Usage

```bash
# 1. CESM 2.1.5 with its externals
git clone -b release-cesm2.1.5 https://github.com/ESCOMP/CESM.git cesm215
cd cesm215 && ./manage_externals/checkout_externals && cd ..

# 2. PUMAS at the pinned commit
git clone https://github.com/ESCOMP/PUMAS.git
git -C PUMAS checkout e7377aeeff15acf28c8edf42e9c50b6e89f7de11

# 3. Patch CAM
PUMAS_interface_215/scripts/apply_interface.sh PUMAS cesm215/components/cam

# 4. Create a case and add the PUMAS sources
cesm215/cime/scripts/create_newcase --case my_case --compset F2000climo --res f09_g17 --run-unsupported
PUMAS_interface_215/scripts/apply_interface.sh PUMAS cesm215/components/cam my_case   # CAM is already patched; copies the PUMAS sources
cp PUMAS_interface_215/namelists/user_nl_cam.pumas my_case/user_nl_cam
cd my_case && ./case.setup && ./case.build && ./case.submit
```

The simulations used the grid `f09_g17`, as in
[mg2_limiter_update](https://github.com/diegovillanueva/mg2_limiter_update).

Step 4 can also be done by hand: copy the nine files `pumas_kinds`,
`pumas_gamma_function`, `micro_pumas_utils`, `micro_pumas_diags`,
`pumas_stochastic_collect_tau`, `module_neural_net`, `tau_neural_net_quantile`,
`ML_fixer_check` and `micro_pumas_v1` (`.F90`) from the PUMAS clone into
`my_case/SourceMods/src.cam/`. Alternatively, pass the PUMAS directory to CAM
with `./xmlchange --append CAM_CONFIG_OPTS="-usr_src <dir>"`, where `<dir>`
holds only these nine files; the other files in the PUMAS repository
(`micro_pumas_ccpp`, `micro_pumas_tempfix`, `micro_mg1_0`) must not be
compiled, because they need CCPP or clash with CAM.

### Optional PUMAS patch set

Before step 4, apply the PUMAS patches to the pinned PUMAS clone:

```bash
git -C PUMAS apply --check ../PUMAS_interface_215/patches_pumas/*.patch
git -C PUMAS apply ../PUMAS_interface_215/patches_pumas/*.patch
```

`apply_interface.sh` then also copies `micro_pumas_sppe.F90` into the case.
The controls are module variables with defaults that reproduce upstream
PUMAS; a host model sets them through `micro_pumas_sppe_set`. The CAM-side
namelist that calls it is not part of this repository.

The patches carry only the modified lines with diff context. Compared with
the development source used for the simulations, the patched files differ
only in comments (emoji markers and a fork name removed); the code lines are
identical.

### Graupel

`user_nl_cam.pumas_graupel` adds two advected constituents. CAM `configure`
counts tracers before it reads this switch, so a graupel case also needs
`./xmlchange --append CAM_CONFIG_OPTS="-nadv <n+2>"`, where `n` is the `nadv`
value in `Buildconf/camconf/config_cache.xml`, followed by `./case.setup --reset`
and `./case.build --clean-all`. Without it, initialisation stops with
`cnst_add: advected tracer index greater than pcnst`.

### CALIPSO cloud-top phase fields

Stock CAM 6 COSP (`cam_cesm2_1_rel_60`) writes `CLD_CAL_TMPLIQ` and
`CLD_CAL_TMPICE` swapped: in COSP2 `lidarcldtmp` index 2 is ice and index 3
is liquid, but stock CAM maps them the other way. This repository does not
modify COSP, so runs built from it get swapped fields (the
DustOnly-NieSing-PUMAS simulations included). Apply the fix from
[cam6_cosp_calipso_diag](https://github.com/diegovillanueva/cam6_cosp_calipso_diag)
or swap the two fields in post-processing.

### Validation

`git apply --check` of all patches passes on a clean `cam_cesm2_1_rel_60`
checkout, and the patched files are identical to the CAM source used for the
simulations. The PUMAS patches apply cleanly to a clean checkout of the
pinned PUMAS commit.

## Versions

- CESM `release-cesm2.1.5` (`7a6c5b0d4e045085633dd9553cdd6aa8a8ea728d`), CAM `cam_cesm2_1_rel_60` (`a03b84b7c4e34f965b115686f22a043b85739e56`).
- PUMAS `https://github.com/ESCOMP/PUMAS.git`, branch `main_cam`, commit `e7377aeeff15acf28c8edf42e9c50b6e89f7de11` (merge of PR #78, 2 September 2026).

The pins are in `versions.env`.

## Licence and citation

BSD 3-Clause for the content of this repository (patch content, scripts,
namelists and documentation); see `LICENSE`. The patches modify CESM2/CAM6
source code, copyright UCAR, which remains under the CESM2 terms of use, and
PUMAS is not redistributed and keeps its own terms; see `NOTICE`.

Please cite this software, [doi:10.5281/zenodo.24365680](https://doi.org/10.5281/zenodo.24365680); the citation metadata are in `CITATION.cff`.

Related repositories:

- [mg2_limiter_update](https://github.com/diegovillanueva/mg2_limiter_update) ([doi:10.5281/zenodo.24365669](https://doi.org/10.5281/zenodo.24365669)): droplet freezing limiter and microphysics switches for MG2 (CESM 2.1.5 default), with the run configurations.
- [cam6_cosp_calipso_diag](https://github.com/diegovillanueva/cam6_cosp_calipso_diag) ([doi:10.5281/zenodo.24365675](https://doi.org/10.5281/zenodo.24365675)): COSP, CALIPSO/CloudSat and cloud-top diagnostics, including the fix of the swapped `CLD_CAL_TMPLIQ`/`CLD_CAL_TMPICE` fields.
- [pumas_limiter_update](https://github.com/diegovillanueva/pumas_limiter_update) ([doi:10.5281/zenodo.24365685](https://doi.org/10.5281/zenodo.24365685)): the droplet freezing limiter for PUMAS, applied on top of PUMAS_interface_215.

## Contact

Diego Villanueva, Institute for Atmospheric and Climate Science, ETH Zurich (GitHub: diegovillanueva).
