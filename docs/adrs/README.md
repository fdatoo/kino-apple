# Architecture Decision Records

This directory holds Architecture Decision Records (ADRs) for Kino Apple. An ADR
captures a single cross-cutting technical decision: the context that forced it,
the choice that was made, and the consequences that follow.

## When to write one

Write an ADR when the decision:

- spans more than one app or KinoKit target, or affects how they interact;
- is something a future contributor (or future you) is likely to ask "why?"
  about;
- is hard or expensive to reverse - code generation, mDNS library choice,
  formatting overrides, persistence strategy, auth model, release model.

Do **not** write an ADR for routine implementation choices that live inside one
module and can be changed without coordination. Those belong in code, in a
design spec under `docs/agents/specs/`, or in the PR description.

## Format

Nygard-lite. Each ADR is a single Markdown file with these sections:

- **Status** - `Proposed`, `Accepted`, or `Superseded by ADR-NNNN`.
- **Date** - ISO date the decision was accepted.
- **Context** - what forced the decision, the constraints, what was tried or
  considered.
- **Decision** - the choice, stated plainly.
- **Consequences** - what follows from the choice: workflows it enables,
  workflows it forecloses, ongoing costs, things it commits the project to.

Keep ADRs short. Long ADRs are usually two ADRs.

## Naming

`NNNN-short-slug.md` where `NNNN` is a zero-padded four-digit number,
monotonic, and the slug describes the decision in a few words.

## Index

- [ADR-0001 — swift-openapi-generator for API bindings](0001-swift-openapi-generator-for-api-bindings.md)
