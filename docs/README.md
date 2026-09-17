# Documentation

PocketBonham has three useful starting points: the [portfolio overview](../README.md), the [player guide](User-Guide.md), and the [developer guide](Development.md). An AI coding agent should begin with [AGENTS.md](../AGENTS.md), then read [AI_CONTEXT.md](../AI_CONTEXT.md).

## Product and development

| Document | Purpose |
|---|---|
| [User Guide](User-Guide.md) | Sequencing, pads, locks, motion, saving, chains and everyday behavior |
| [Development](Development.md) | Toolchain, simulator/device builds, source map and project generation |
| [Testing](Testing.md) | Automated checks, physical acceptance and evidence conventions |
| [Troubleshooting](Troubleshooting.md) | Audio, kits, storage, builds and installation problems |
| [Data Model](Data-Model.md) | Pattern/chain relationships, versioning, persistence and recovery |
| [Audio Architecture](Audio-Architecture.md) | Thread ownership, sample clock, voices, DSP and lifecycle |
| [Kit Format](Kit-Format.md) | Manifest contract, supported files and reproducible kit integration |
| [Asset and License Notes](Asset-and-License-Notes.md) | Sample provenance, generated fixtures and current licensing status |

## Decisions and delivery evidence

| Document | Purpose |
|---|---|
| [AI Context](../AI_CONTEXT.md) | Current state, owner decisions, next work and important invariants |
| [Changelog](../CHANGELOG.md) | Delivered features and the simultaneous-hat correction |
| [Milestones](Milestones.md) | Completed implementation and remaining release gates |
| [Validation Report](Validation-Report.md) | Historical runs, latest corrections and limits of verification |
| [Drum Kit 1 Integration](Kit-1-Integration.md) | Exact source-file mapping and validation |
| [Hat Layering Fix](Hat-Layering-Fix.md) | Reproduction, behavior change and regression evidence |
| [Original Software Specification](PocketBonham-Software-Specification.md) | Original product requirements; read with subsequent owner decisions |

## Reading the evidence

`evidence/` contains compact test output and simulator screenshots. Build products, raw `.xcresult` bundles, signing material and user libraries are not committed. Repository paths and device identifiers in published evidence are generalized where appropriate; measured results and failure messages are retained.

The original specification is a historical requirements document. In particular, its closed-hat-wins collision rule was explicitly superseded by the owner's request for simultaneous hats to sound together. The current rule is documented in [Hat Layering Fix](Hat-Layering-Fix.md).
