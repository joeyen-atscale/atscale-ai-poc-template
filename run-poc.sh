#!/usr/bin/env bash
# =============================================================================
# AtScale AI POC — one-command provisioning pipeline
# =============================================================================
# Chains @atscale/ps-utils operations to stand up a complete AI-ready POC:
#   schema -> semantic model -> (synthetic data) -> deploy -> MCP-queryable
#
# Prereqs:
#   - Node 18+ and `npm i -g @atscale/ps-utils`  (provides `atscale-utils`)
#   - connections.yaml filled in (see connections.example.yaml)
#   - poc.config.sh filled in   (see poc.config.example.sh)
#
# Usage:
#   ./run-poc.sh                # full pipeline
#   ./run-poc.sh model          # just (re)generate the SML
#   ./run-poc.sh data           # just synthetic data
#   ./run-poc.sh deploy         # just deploy to AtScale
#   ./run-poc.sh bi             # just BI artifacts
#   ./run-poc.sh verify         # list model errors / smoke test
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"
[ -f poc.config.sh ] || { echo "Missing poc.config.sh (cp poc.config.example.sh poc.config.sh)"; exit 1; }
[ -f connections.yaml ] || { echo "Missing connections.yaml (cp connections.example.yaml connections.yaml)"; exit 1; }
# shellcheck source=/dev/null
source poc.config.sh

CONN="--connection-file connections.yaml"
SML_DIR="${POC_OUT_DIR}/sml"
MODEL_FILE="${POC_OUT_DIR}/model.yaml"
NS_FILE="${POC_OUT_DIR}/namespace.yaml"
SHAPE_FILE="${POC_OUT_DIR}/data-shape.yaml"
INSTALL_FILE="${POC_OUT_DIR}/values.yaml"
mkdir -p "${POC_OUT_DIR}"

au() { echo "+ atscale-utils $*"; atscale-utils "$@"; }

# -----------------------------------------------------------------------------
step_install() {
  echo "== [0] Rendering AtScale install values.yaml WITH MCP server enabled =="
  # Provisions the AI layer: --enable-mcp turns on the atscale-mcp sub-chart (/mcp, :3003),
  # which is what Claude/any LLM connects to for natural-language querying.
  au generate-atscale-install-yaml \
    --hostname "${POC_ATSCALE_HOSTNAME}" \
    --enable-mcp true \
    --minimal \
    ${POC_LICENSE_KEY:+--license-key "${POC_LICENSE_KEY}"} \
    --output-file "${INSTALL_FILE}"
  echo "   Wrote ${INSTALL_FILE}. Deploy with your Helm/k8s flow, e.g.:"
  echo "     helm upgrade --install atscale atscale/atscale -f ${INSTALL_FILE}"
}

# -----------------------------------------------------------------------------
step_model() {
  echo "== [1/4] Generating SML semantic model from ${POC_SOURCE_CONN} =="
  au generate-sml-from-connection \
    $CONN \
    --connection-name "${POC_SOURCE_CONN}" \
    --model-name "${POC_MODEL_NAME}" \
    --output-dir "${SML_DIR}" \
    --pii-severity "${POC_PII_SEVERITY}" \
    --sample-size "${POC_SAMPLE_SIZE}"
  # The vertical inference plugins (${POC_VERTICAL}) auto-enrich measures/hierarchies
  # with business-friendly names — exactly what makes the model good for NL/LLM querying.

  echo "   Extracting portable model.yaml (drives namespace + BI generation)"
  au extract-model-from-sml \
    --sml-dir "${SML_DIR}" \
    --output-model-file "${MODEL_FILE}"
}

# -----------------------------------------------------------------------------
step_data() {
  [ "${POC_USE_SYNTHETIC}" = "true" ] || { echo "== [2/4] Synthetic data disabled (POC_USE_SYNTHETIC=false), skipping =="; return 0; }
  echo "== [2/4] Profiling source + generating SAFE synthetic data into ${POC_SYNTH_SCHEMA} =="
  # --preserve-meta-data keeps the REAL table/column names in the fingerprint so the
  # generated data matches the model built by step_model (which used the real schema).
  # Without it, synthetic tables get synthetic names and the deployed model won't resolve.
  au extract-data-shape-from-connection \
    $CONN \
    --connection-name "${POC_SOURCE_CONN}" \
    --sml-path "${SML_DIR}" \
    --output-file "${SHAPE_FILE}" \
    --preserve-meta-data true

  # Generate synthetic rows into a SEPARATE demo schema (never overwrite source data).
  au generate-data-from-data-shape-to-connection \
    --input-file "${SHAPE_FILE}" \
    $CONN \
    --connection-name "${POC_SYNTH_CONN}" \
    --schema "${POC_SYNTH_SCHEMA}" \
    --scale-factor "${POC_SYNTH_SCALE_FACTOR}" \
    --create-tables \
    --drop-if-exists \
    --preserve-meta-data true
}

# -----------------------------------------------------------------------------
step_deploy() {
  echo "== [3/4] Deploying model to AtScale (${POC_ATSCALE_CONN}) =="
  # Register the git repo that holds the SML (idempotent-ish: ignore if it exists)
  au atscale-create-repo \
    $CONN \
    --atscale-connection-name "${POC_ATSCALE_CONN}" \
    --name "${POC_REPO_NAME}" \
    --url "${POC_REPO_URL}" \
    || echo "   (repo may already exist — continuing)"

  au atscale-deploy-catalog \
    $CONN \
    --atscale-connection-name "${POC_ATSCALE_CONN}" \
    --sml-dir "${SML_DIR}" \
    --repo-name "${POC_REPO_NAME}" \
    --project-name "${POC_MODEL_NAME}"
  echo "   Model deployed. It is now queryable via the AtScale MCP server (/mcp, port 3003)."
}

# -----------------------------------------------------------------------------
step_bi() {
  echo "== [4/4] Generating BI artifacts (before/after-AI comparison assets) =="
  au generate-namespace-from-model \
    --model-file "${MODEL_FILE}" \
    --model-name "${POC_MODEL_NAME}" \
    --title "${POC_NAME} POC Analysis" \
    --output-file "${NS_FILE}"

  au generate-tableau-from-namespace \
    --namespace-file "${NS_FILE}" \
    --model-file "${MODEL_FILE}" \
    --connection-name "${POC_ATSCALE_CONN}" \
    --target-file "${POC_OUT_DIR}/${POC_NAME}.twb" \
    || echo "   (tableau gen optional — continuing)"
}

# -----------------------------------------------------------------------------
step_verify() {
  echo "== Verify: listing model errors =="
  au atscale-list-model-errors \
    $CONN \
    --atscale-connection-name "${POC_ATSCALE_CONN}" \
    || true
  echo
  echo "Next: connect Claude to the AtScale MCP server and ask a natural-language"
  echo "question (e.g. 'what were net sales by week last quarter?'). The MCP server's"
  echo "list_models / describe_model / run_query tools resolve against '${POC_MODEL_NAME}'."
}

# -----------------------------------------------------------------------------
case "${1:-all}" in
  install) step_install ;;
  model)   step_model ;;
  data)    step_data ;;
  deploy)  step_deploy ;;
  bi)      step_bi ;;
  verify)  step_verify ;;
  # 'all' assumes the AtScale instance already exists; run 'install' separately first
  # if you also need to render the install values.yaml.
  all)     step_model; step_data; step_deploy; step_bi; step_verify ;;
  *) echo "Unknown step: $1 (use: install|model|data|deploy|bi|verify|all)"; exit 1 ;;
esac
echo "Done."
