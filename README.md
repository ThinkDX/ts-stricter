# TS Stricter

**Migrate an un-strict TypeScript codebase to `strict` mode, one pull request at a time — without ever blocking a build.**

`ts-stricter` is a GitHub Action that counts the TypeScript errors your code _would_ have under `strict` mode on your PR branch (**HEAD**) and on the target branch (**BASE**), and **fails the check only if the count went up**. Existing errors are grandfathered in; new ones are not. Your team chips away at the backlog on its own schedule, and the number only ever goes down.

---

## The problem

You want `strict: true`, but flipping it on lights up thousands of errors and breaks every build. So it stays off, and the codebase keeps accruing the exact problems strict mode would have caught. A big-bang migration never gets prioritized.

## The idea: a ratchet, not a cliff

Instead of demanding zero errors, `ts-stricter` enforces **"no more errors than before."** Each PR is allowed to leave the strict-error count flat or lower it — never raise it. The build is never blocked by the pre-existing backlog, but the backlog can only shrink.

---

## Recommended setup: strict **on** in the editor, **off** in the build

> **Developers won't fix what they can't see.** If strict errors only surface in CI, people discover at PR time that they accidentally added some — which is annoying, so they skip or work around the check instead of fixing it. The fix is to make strict errors visible *while you code*, and keep them out of the build so nothing breaks.

The pattern that makes this work is **two tsconfigs**:

**`tsconfig.json`** — strict **on**. This is what your editor (VS Code, etc.) reads, so every developer sees strict errors as red squiggles in real time.

```jsonc
{
  "compilerOptions": {
    "strict": true
    // ...the rest of your options
  }
}
```

**`tsconfig.build.json`** — strict **off**, for anything that must keep compiling today (bundlers, `tsc --build`, CI type-checks):

```jsonc
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "strict": false
  }
}
```

Point your build/type-check scripts at the relaxed config so they don't fail on the existing backlog:

```jsonc
// package.json
{
  "scripts": {
    "build": "tsc -p tsconfig.build.json",
    "typecheck": "tsc -p tsconfig.build.json --noEmit"
  }
}
```

Then let **`ts-stricter` be the thing that enforces strictness** — it runs with `--strict` forced on (`strict-override: true`, the default) and only fails when the count increases. Developers see errors live, builds stay green, and the ratchet does the rest.

---

## Quick start

Create `.github/workflows/ts-stricter.yml`:

```yaml
name: TS Stricter

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  ts-stricter:
    runs-on: ubuntu-latest
    steps:
      - uses: thinkdx/ts-stricter@v2
```

That's it. On every PR the action installs deps, runs `tsc --strict` on BASE and HEAD, and fails if HEAD has more errors.

### A more configured example

```yaml
- uses: thinkdx/ts-stricter@v2
  with:
    package-manager: pnpm          # npm | yarn | pnpm
    node-version-file: .nvmrc      # or node-version: '20'
    working-directory: ./app
    tsconfig: tsconfig.json        # strict is forced regardless of what this says
    prebuild-command: pnpm codegen # e.g. generate types before tsc
```

---

## How it works

1. Check out **BASE**, install dependencies, run `tsc --strict --noEmit`, count errors.
2. Check out **HEAD** (the merge commit by default), install, run the same, count errors.
3. Compare. If HEAD > BASE, fail the check (unless `fail-on-increase: false`).

The error count is parsed from `tsc`'s summary line (`Found N errors…`), so a clean run counts as `0`.

---

## Workspaces / monorepos

For repos with several packages, each with its **own `tsconfig.json`**, run in workspace mode. Each package is counted independently and **any** package regressing fails the check.

```yaml
- uses: thinkdx/ts-stricter@v2
  with:
    is-workspace: true
    workspace-packages: |
      packages/app, packages/ui, packages/server
    workspace-prebuild-command: pnpm -r build   # runs once at the repo root first
```

Per-package error counts and differences are exposed as JSON outputs (`package-errors`, `package-differences`).

---

## Inputs

| Input | Default | Description |
| --- | --- | --- |
| `working-directory` | `.` | Directory to run TypeScript in. |
| `package-manager` | `npm` | `npm`, `yarn`, or `pnpm`. |
| `cache-dependencies` | `true` | Cache the package manager's store between runs. |
| `install-command` | _(auto)_ | Override the default install command. |
| `node-version` | _(none)_ | Node.js version to set up. |
| `node-version-file` | _(none)_ | Path to a version file (e.g. `.nvmrc`). |
| `tsconfig` | `tsconfig.json` | tsconfig to use, relative to `working-directory` (or to each package in workspace mode). |
| `strict-override` | `true` | Force `--strict` regardless of the tsconfig. |
| `prebuild-command` | _(none)_ | Command to run before `tsc` (e.g. codegen). |
| `prebuild-working-directory` | `.` | Working directory for `prebuild-command`. |
| `use-head-commit` | `false` | Check out the PR head SHA instead of the merge commit. |
| `is-workspace` | `false` | Enable multi-package workspace mode. |
| `workspace-packages` | _(none)_ | Comma-separated package directories (workspace mode). |
| `workspace-prebuild-command` | _(none)_ | Command run once at the workspace root before counting. |
| `fail-on-increase` | `true` | Fail the workflow when the error count increases. Set `false` to report only. |

## Outputs

| Output | Description |
| --- | --- |
| `head-errors` | Total strict errors on HEAD. |
| `base-errors` | Total strict errors on BASE. |
| `error-difference` | `head - base`. |
| `errors-increased` | `true` / `false`. |

In workspace mode the `typescript` and `compare` sub-actions additionally expose `package-errors` and `package-differences` as JSON maps keyed by package directory.

---

## Composite sub-actions

`ts-stricter` is built from three composable actions you can also use on their own:

| Action | Purpose |
| --- | --- |
| `thinkdx/ts-stricter/install@v2` | Set up Node + the package manager and install deps (with caching). |
| `thinkdx/ts-stricter/typescript@v2` | Run `tsc` and output the error count (single package or workspace). |
| `thinkdx/ts-stricter/compare@v2` | Compare two counts (or two per-package maps) and fail on increase. |

The heavy lifting lives in plain shell scripts under [`scripts/`](./scripts), which the actions invoke — so the logic is unit-testable without GitHub (see below).

---

## Local development & testing

The error-counting and comparison logic is covered by a fast local harness — no GitHub, no PR required:

```bash
./test/run-tests.sh
```

It runs against fixture projects (a single package and a multi-`tsconfig` workspace) and asserts strict enforcement, workspace counting, and every comparison outcome. See [`test/README.md`](./test/README.md) for details and how to add fixtures. The same suite runs in CI on Node 18/20/22.

---

## Notes

- **Pull-request events only.** The action compares HEAD vs BASE, so it expects a `pull_request` trigger.
- **Custom Node/setup steps** belong _before_ this action if you need them.
- **`tsconfig` must exist** where the action runs; otherwise `tsc` falls back to its defaults.

## Contributing

Issues and PRs welcome. If you change the scripts, run `./test/run-tests.sh` and add a fixture/assertion for the behavior.

## License

[MIT](LICENSE).
