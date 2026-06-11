# AtScale AI POC Template

A repeatable scaffold for standing up an **AI-queryable AtScale semantic layer POC**
on top of [`@atscale/ps-utils`](https://github.com/AtScaleInc/ps-utils).

The hard part of any "talk to your data" demo isn't the LLM — it's building a clean,
business-friendly **semantic model** for the LLM to query, and (often) safe demo data.
`ps-utils` automates exactly that. This template wires its operations into one command.

## What this gives you

```
 customer DB schema
        │  generate-sml-from-connection   (+ vertical inference, PII exclusion)
        ▼
 SML semantic model ──► extract-model-from-sml ──► model.yaml
        │                                              │ generate-namespace / -tableau
        │  (optional) synthetic data                   ▼
        │  extract-data-shape ─► generate-data    BI artifacts (.twb, etc.)
        ▼
 atscale-create-repo + atscale-deploy-catalog
        ▼
 AtScale instance  ──►  atscale-mcp server (/mcp :3003)  ◄── Claude / any LLM
        │                                                     list_models
        │  execute-atscale-query-harness (validate)           describe_model
        ▼                                                      run_query
   "what were net sales by week last quarter?"  → natural-language answers
```

The **AI layer is the AtScale MCP server**, which `ps-utils` itself can enable when it
renders the install (`generate-atscale-install-yaml --enable-mcp true`, port 3003).
So the entire POC — model, data, deployment, and the AI endpoint — is provisionable
from this toolkit.

## Prerequisites

- Node 18+, then `npm install -g @atscale/ps-utils` (provides the `atscale-utils` CLI)
- An AtScale instance with the MCP server enabled
- Access to the customer's source warehouse (read-only is enough)

## Quickstart

```bash
cp poc.config.example.sh poc.config.sh        # fill in customer/model/vertical
cp connections.example.yaml connections.yaml  # fill in DB + AtScale credentials
./run-poc.sh                                  # full pipeline
```

Run a single phase while iterating:

```bash
./run-poc.sh install   # (phase 0) render values.yaml with the MCP/AI server enabled
./run-poc.sh model     # (re)generate the SML semantic model
./run-poc.sh data      # profile source + generate synthetic data
./run-poc.sh deploy    # register repo + deploy catalog to AtScale
./run-poc.sh bi        # namespace + Tableau workbook
./run-poc.sh verify    # list model errors + next steps
```

## Supported verticals

`generate-sml-from-connection` ships inference plugins that auto-enrich the model with
industry-aware names/hierarchies (this is what makes NL querying feel good). Set
`POC_VERTICAL` to one of:

`education`, `energy-utilities`, `financial-services`, `government`, `healthcare`,
`human-resources`, `insurance`, `logistics`, `manufacturing`, `media-advertising`,
`pharma`, `real-estate`, `retail-ecommerce`, `telecom`, `travel-hospitality`.

`resources/namespaces/<vertical>/overview.yaml` in `ps-utils` provides pre-built
example analyses per vertical you can lift for the demo script.

## Connecting Claude to the result

After `deploy`, the model is live behind the AtScale MCP server. Point an MCP client
(Claude Desktop / Claude Code / claude.ai) at the instance's `/mcp` endpoint and the
`list_models` / `describe_model` / `run_query` tools resolve against your POC model.

## Notes & gotchas (from the ps-utils source)

- **Auth**: deploy needs both an `apiToken` *and* username/password on the same `users:`
  entry — the token covers REST calls, user/pass acquires the deploy session cookie.
- **PII**: `--pii-severity MEDIUM` (default) excludes detected PII columns from the model.
  Combined with synthetic data, this keeps demos clean of real customer values.
- **Repo creation** is not strictly idempotent; `run-poc.sh` tolerates "already exists".
- Flags here were read from the `ps-utils` operation sources; if you bump the package
  version, re-check `atscale-utils <op> --help`.
