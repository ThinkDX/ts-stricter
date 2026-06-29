# Test harness

Fast, local tests for the logic that powers `ts-stricter` — error counting and
HEAD-vs-BASE comparison — without needing GitHub or a real pull request.

```bash
./test/run-tests.sh
```

On first run it installs a single copy of TypeScript under `test/node_modules`
(shared by every fixture), then exercises the scripts in `../scripts` against
the fixtures below. It exits non-zero if any assertion fails. The same script
runs in CI (`.github/workflows/test.yml`) across Node 18/20/22.

## What it covers

- **Strict enforcement** — the `single` fixture reports `0` errors with
  `strict: false` and `2` under `--strict`, proving `strict-override` works.
- **Workspaces / multiple tsconfigs** — the `workspace` fixture has two packages
  (`packages/a`, `packages/b`), each with its own `tsconfig.json`, and asserts
  the per-package JSON and the total.
- **Comparison semantics** — no-change passes, an increase fails (exit 1),
  a reduction passes, and `fail-on-increase: false` downgrades a failure.
- **Slashed package names** — workspace comparison uses package paths like
  `packages/a` as JSON keys (a case the original `jq` code got wrong).

## Fixtures

| Fixture                | Shape                          | Strict errors |
| ---------------------- | ------------------------------ | ------------- |
| `fixtures/single`      | one package                    | 2             |
| `fixtures/workspace`   | `packages/a` + `packages/b`    | 2 + 1 = 3     |

Each fixture sets `strict: false` in its `tsconfig.json` and contains code that
only errors under strict mode, so the count is meaningfully different with and
without enforcement.

## Adding a fixture

1. Create a directory under `fixtures/` with a `tsconfig.json` (`strict: false`,
   `noEmit: true`, `skipLibCheck: true`) and some `.ts` source with a known
   number of strict-only errors.
2. Add assertions in `run-tests.sh` using the existing helpers
   (`run_script`, `out`, `assert_eq`).

The scripts read all configuration from environment variables (`TSCONFIG`,
`STRICT_OVERRIDE`, `IS_WORKSPACE`, `WORKSPACE_PACKAGES`, `HEAD_ERRORS`, …) and
`TSC_CMD` lets the harness point at the local TypeScript install, so no GitHub
context is required.
