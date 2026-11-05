# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A technical test for an auto-parts store (refaccionaria): a Rails app that reads a source Excel of engine parts (`docs/input/data_prueba_tecnica.xlsx`, sheet `Origen`) and generates a catalog Excel in the same shape as `docs/input/ejemplo_prueba_tecnica.xlsx`, filled with **real** applications, interchanges and attributes per part.

**`docs/DESIGN_BRIEF.md` is the primary spec** (written in Spanish). Read it before designing or implementing anything. At the time of writing, the repo is only a fresh Rails 8 skeleton; the pipeline described below is the *proposed* architecture, not existing code.

## Commands

Ruby 3.3.5, Rails 8.1, SQLite, Solid Queue/Cache/Cable (no Redis/Postgres). Tests use Minitest.

```bash
bin/setup                 # install gems, prepare DB, start server (--skip-server to skip)
bin/dev                   # run the server
bin/rails test            # all tests
bin/rails test test/models/foo_test.rb        # one file
bin/rails test test/models/foo_test.rb:42     # one test, by line
bin/rubocop               # lint (rubocop-rails-omakase)
bin/ci                    # full local CI: setup, rubocop, bundler-audit, importmap audit, brakeman, tests, seeds
```

## Hard requirements (from the evaluator)

- **Determinism:** running the same dataset twice must produce identical results. This drives most design choices:
  - Every external fetch is persisted as a snapshot (`url, body, sha256, fetched_at`) and reused; no re-download unless explicitly forced (`FORCE_REFRESH`). Snapshots double as test fixtures — adapter tests must run without network.
  - Any LLM use: only for unstructured text (e.g. PDFs), temperature 0, JSON-schema structured output, cached by input hash (never call the model when cached).
  - Every output sheet has a total, stable row ordering; idempotency is tested by comparing workbook *contents* across two runs (not `.xlsx` bytes, which carry timestamps).
- **Source of truth is the manufacturer's official site/catalog.** The `Descripcion` field in the input is noisy (interchange numbers, abbreviated vehicle, year range `AA/AA`, free notes) and must only be used to *find* and *validate* data, never as final output. If data isn't found, mark it as not found — never invent. Each datum keeps its source URL.
- Strict TDD (red → green → refactor).

## Proposed architecture (see brief §5)

Upload file → run screen with per-part progress (Turbo Streams) → download Excel. One job per part plus a finalizer job that builds the workbook. Pipeline steps are service objects:

1. **Import** — read Excel (`roo`) → `SourceItem`.
2. **DescriptionParser** — deterministic regex + dictionaries → structured hints.
3. **Fetch** — one adapter per manufacturer (`Sources::Elgin`, `Sources::Fraco`, …) behind a common interface. Known sources: ELGIN → `catalog.elginind.com` (HTML); FRACO → PDF spec sheet at `https://www.fraco.com.mx/QRMX/{part_number}.pdf` (use `pdftotext -layout`). REXITE, SAFETY, REVO still need discovery spikes.
4. **Extract** — snapshot → applications / interchanges / attributes.
5. **Reconcile** — official data vs. description hints; record matches/discrepancies.
6. **Normalize** — versioned YAML dictionaries for brands, product names, taxonomy, attribute classes/units, vehicle names.
7. **Export** — `caxlsx`.

## Output contract

Sheets and columns must match the example workbook exactly (names include accents): `Origen`, `Métricas`, `Aplicaciones`, `Intercambios`, `Atributos`, `Catálogo`. Column lists, normalization examples (brands, product names, taxonomy) and the `Métricas` layout are in brief §3. Notable rules: `Aplicaciones` is exploded to one row per submodel × year × engine, `Mercado` = `MEX`; `Intercambios.Origen` is `Aftermarket`/`OEM`.

Useful validation cases: FRACO `FSX-5840299` appears in the example and its PDF should reproduce the example's rows; `RM-152 ↔ DM-152` and `TK1283-1 ↔ DDM-77020` appear in both files.

## Contexto del desarrollador

- Estoy en transición a desarrollo de software; explícame las decisiones técnicas en español y en términos simples.
- Responde en español. Código, nombres de variables y commits en inglés.
- Commits pequeños y frecuentes.
- Registra cada decisión importante en `docs/DECISIONS.md` con fecha y hora.
- Superpowers specs and plans live under `docs/`.
