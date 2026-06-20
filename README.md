# AtScale AI POC Template

One command to stand up an AI-queryable AtScale semantic-layer POC — model, demo data, deployment, and the MCP endpoint an LLM talks to — by chaining [`@atscale/ps-utils`](https://github.com/AtScaleInc/ps-utils) operations.

## Why it exists

The hard part of a "talk to your data" demo isn't the LLM. It's everything underneath: a clean, business-friendly semantic model for the LLM to query, and demo data safe enough to show a customer. An LLM pointed at a raw warehouse guesses; pointed at a well-named semantic model with real hierarchies and measures, it answers. `ps-utils` builds that model and that data; this template wires its operations into a single pipeline so a POC is a config file and a script, not a week of plumbing.

## What the pipeline does

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
        │  atscale-list-model-errors (verify)                 describe_model
        ▼                                                      run_query
   "what were net sales by week last quarter?"  → natural-language answers
```

The AI layer is the AtScale MCP server. `ps-utils` enables it when it renders the install (`generate-atscale-install-yaml --enable-mcp true`, port 3003), so the whole POC — model, data, deployment, and the AI endpoint — comes out of one toolkit.

## Prerequisites

- Node 18+, then `npm install -g @atscale/ps-utils` (provides the `atscale-utils` CLI)
- An AtScale instance with the MCP server enabled
- Access to the customer's source warehouse — read-only is enough

## Quickstart

```bash
cp poc.config.example.sh poc.config.sh        # customer slug, model name, vertical
cp connections.example.yaml connections.yaml  # DB + AtScale credentials
./run-poc.sh                                  # full pipeline
```

Both copied files are git-ignored — they hold credentials and customer config, and never get committed.

`./run-poc.sh` with no argument runs the full pipeline against an AtScale instance that already exists. Run a single phase while iterating:

```bash
./run-poc.sh install   # phase 0: render values.yaml with the MCP/AI server enabled
./run-poc.sh model     # (re)generate the SML semantic model
./run-poc.sh data      # profile source + generate synthetic data
./run-poc.sh deploy    # register repo + deploy catalog to AtScale
./run-poc.sh bi        # namespace + Tableau workbook
./run-poc.sh verify    # list model errors + next steps
```

`install` is separate from the full run on purpose: `all` assumes the instance is up, so render and deploy the install values first if you also need to stand up AtScale itself.

## How it works

Six phases, each one or two `ps-utils` operations:

| Phase | Operation(s) | What it produces |
|---|---|---|
| `install` | `generate-atscale-install-yaml` | `values.yaml` with the MCP server enabled (port 3003) |
| `model` | `generate-sml-from-connection`, `extract-model-from-sml` | SML model + a portable `model.yaml` |
| `data` | `extract-data-shape-from-connection`, `generate-data-from-data-shape-to-connection` | synthetic rows in a separate demo schema |
| `deploy` | `atscale-create-repo`, `atscale-deploy-catalog` | the model, live on the instance |
| `bi` | `generate-namespace-from-model`, `generate-tableau-from-namespace` | namespace + a `.twb` workbook |
| `verify` | `atscale-list-model-errors` | model error list + next steps |

The synthetic-data phase writes into a separate demo schema and never touches the source — `POC_SYNTH_CONN` is a distinct connection from `POC_SOURCE_CONN`. It passes `--preserve-meta-data` so the generated tables keep the real schema's names; otherwise the deployed model, built from the real schema, wouldn't resolve against the synthetic data.

## Supported verticals

`generate-sml-from-connection` ships inference plugins that auto-enrich the model with industry-aware names and hierarchies — the part that makes natural-language querying feel good. Set `POC_VERTICAL` to one of:

`education`, `energy-utilities`, `financial-services`, `government`, `healthcare`, `human-resources`, `insurance`, `logistics`, `manufacturing`, `media-advertising`, `pharma`, `real-estate`, `retail-ecommerce`, `telecom`, `travel-hospitality`.

`resources/namespaces/<vertical>/overview.yaml` in `ps-utils` carries pre-built example analyses per vertical you can lift for the demo script.

## Connecting Claude to the result

After `deploy`, the model is live behind the AtScale MCP server. Point an MCP client (Claude Desktop, Claude Code, or claude.ai) at the instance's `/mcp` endpoint, and the `list_models`, `describe_model`, and `run_query` tools resolve against your POC model. Then ask in plain language — "what were net sales by week last quarter?" — and the model answers.

## Notes & gotchas

Read from the `ps-utils` operation sources:

- **Auth needs both halves.** Deploy wants an `apiToken` *and* username/password on the same `users:` entry — the token covers REST calls, the user/pass acquires the deploy session cookie.
- **PII exclusion.** `--pii-severity MEDIUM` (the default) drops detected PII columns from the model. With synthetic data on, demos stay clear of real customer values.
- **Repo creation isn't strictly idempotent.** `run-poc.sh` tolerates an "already exists" and continues.
- **Flags track the package version.** These were read from the `ps-utils` operation sources; if you bump the package, re-check `atscale-utils <op> --help`.

## Status

A working shell pipeline over the `@atscale/ps-utils` CLI — no code of its own beyond `run-poc.sh` and two example config files. It does exactly what the script does, no more. Treat it as a starting point to copy and adapt per POC, not a managed tool.
