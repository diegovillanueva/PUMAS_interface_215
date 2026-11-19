#!/usr/bin/env bash
# Patch CESM 2.1.5 CAM so that it can run PUMAS as micro_mg_version = 3.
# Usage: scripts/apply_interface.sh <PUMAS_DIR> <CAM_DIR> [<CASE_DIR>]
#   PUMAS_DIR  clone of ESCOMP/PUMAS checked out at PUMAS_COMMIT (versions.env)
#   CAM_DIR    <CESM_ROOT>/components/cam at cam_cesm2_1_rel_60
#   CASE_DIR   optional: copy the nine PUMAS source files (ten with patches_pumas/ applied)
#              into <CASE_DIR>/SourceMods/src.cam
set -euo pipefail

usage="usage: apply_interface.sh <PUMAS_DIR> <CAM_DIR> [<CASE_DIR>]"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pumas="${1:?${usage}}"
cam="${2:?${usage}}"
case_dir="${3:-}"
# shellcheck source=/dev/null
source "${here}/versions.env"

check_head() {
    local dir="$1" want="$2" name="$3" head
    head="$(git -C "${dir}" rev-parse HEAD 2>/dev/null)" || { echo "ERROR: ${dir} is not a git checkout" >&2; exit 1; }
    if [[ "${head}" != "${want}" ]]; then
        echo "ERROR: ${name} HEAD ${head} is not ${want}" >&2
        exit 1
    fi
}
check_head "${pumas}" "${PUMAS_COMMIT}" "PUMAS"
check_head "${cam}" "${CAM_COMMIT}" "CAM"

if git -C "${cam}" apply --reverse --check "${here}"/patches/*.patch 2>/dev/null; then
    echo "CAM already patched: ${cam}"
else
    git -C "${cam}" apply --check "${here}"/patches/*.patch
    git -C "${cam}" apply --whitespace=nowarn "${here}"/patches/*.patch
    echo "Patched CAM: ${cam}"
fi

if [[ -n "${case_dir}" ]]; then
    dest="${case_dir}/SourceMods/src.cam"
    [[ -d "${dest}" ]] || { echo "ERROR: ${dest} not found" >&2; exit 1; }
    for f in pumas_kinds pumas_gamma_function micro_pumas_utils micro_pumas_diags \
             pumas_stochastic_collect_tau module_neural_net tau_neural_net_quantile ML_fixer_check micro_pumas_v1 micro_pumas_sppe; do
        [[ "${f}" == micro_pumas_sppe && ! -f "${pumas}/${f}.F90" ]] && continue
        cp "${pumas}/${f}.F90" "${dest}/"
        echo "${dest}/${f}.F90"
    done
fi
