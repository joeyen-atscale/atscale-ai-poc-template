# =============================================================================
# AtScale AI POC — configuration
# =============================================================================
# Copy to poc.config.sh and fill in. poc.config.sh is git-ignored (secrets).
#   cp poc.config.example.sh poc.config.sh
# Every variable below is consumed by run-poc.sh.

# --- Identity --------------------------------------------------------------
export POC_NAME="acme"                       # short slug for the customer/POC
export POC_MODEL_NAME="SalesModel"           # name of the generated semantic model
export POC_VERTICAL="retail-ecommerce"       # one of the built-in inference verticals (see README)

# --- Source database connection (entry name inside connections.yaml) -------
# The customer's real warehouse. Used to introspect schema + (optionally) profile
# data for synthetic generation. NEVER commit real data into this repo.
export POC_SOURCE_CONN="customer_snowflake"

# --- AtScale instance connection (entry name inside connections.yaml) ------
export POC_ATSCALE_CONN="poc_atscale"

# --- AtScale install (phase 0: ./run-poc.sh install) -----------------------
# Renders values.yaml with the MCP (AI) server enabled. Only needed if you are
# also standing up the AtScale instance itself.
export POC_ATSCALE_HOSTNAME="atscale-poc.example.com"
export POC_LICENSE_KEY=""                    # optional; upload via UI later if blank

# --- Git repo to hold the deployed SML (AtScale Design Center repo) ---------
export POC_REPO_NAME="${POC_NAME}-poc-models"
export POC_REPO_URL="https://github.com/AtScaleInc/${POC_NAME}-poc-models.git"

# --- Synthetic data toggle -------------------------------------------------
# true  = profile source DB, generate synthetic data into a demo schema (safe for demos)
# false = point the model at the real source schema
export POC_USE_SYNTHETIC="true"
export POC_SYNTH_CONN="poc_demo_warehouse"   # connection to WRITE synthetic data into
                                             # (keep separate from POC_SOURCE_CONN — never write to source)
export POC_SYNTH_SCALE_FACTOR="1.0"          # multiply row counts for synthetic gen
export POC_SYNTH_SCHEMA="poc_demo"           # target schema for synthetic tables

# --- Model quality knobs ---------------------------------------------------
export POC_PII_SEVERITY="MEDIUM"             # HIGH | MEDIUM | LOW | none  (exclude PII columns)
export POC_SAMPLE_SIZE="250"                 # rows sampled per table for type inference

# --- Output locations (relative to this template dir) ----------------------
export POC_OUT_DIR="./out/${POC_NAME}"
