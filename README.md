# TS Stricter

This GitHub Action helps you **iteratively migrate** your **unstrict** TypeScript codebase to a **strict** one. It does this by **comparing the TypeScript error count** on your pull request's **HEAD** branch vs. the **BASE** branch and **fails** the workflow if new errors have been introduced.  

By ensuring that your error count never goes up, your team can gradually reduce existing errors over time—eventually reaching a fully strict codebase without sudden disruptions.

## Features

- 🔄 **Flexible Installation**: Support for npm, yarn, and pnpm with customizable install commands
- 💾 **Dependency Caching**: Optional caching to speed up your workflows
- 🛠 **Prebuild Support**: Run custom commands before TypeScript compilation
- ⚙️ **TypeScript Configuration**: Use your own tsconfig.json with strict mode enforcement
- 📊 **Error Tracking**: Detailed error count comparison with configurable failure thresholds
- 🧩 **Modular Design**: Use the full workflow or individual composite actions for custom needs

## Usage

### Basic Usage

In your repository, create or update a GitHub Actions workflow file (e.g. `.github/workflows/compare-tsc-errors.yml`) with the following:

```yaml
name: Compare TSC Errors

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  compare-tsc-errors:
    runs-on: ubuntu-latest
    steps:
      - name: Compare TSC on HEAD vs BASE
        uses: thinkdx/ts-stricter@v2
```

### Advanced Usage

```yaml
name: Compare TSC Errors

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  compare-tsc-errors:
    runs-on: ubuntu-latest
    steps:
      - name: Compare TSC on HEAD vs BASE
        uses: thinkdx/ts-stricter@v2
        with:
          # Installation options
          package-manager: 'yarn'           # npm, yarn, or pnpm (default: npm)
          cache-dependencies: true                # Enable dependency caching (default: true)
          install-command: 'yarn install'   # Custom install command (optional)
          node-version: '18'               # Node.js version (default: 18)
          
          # TypeScript options
          working-directory: './packages/core'  # Directory to run in (default: .)
          tsconfig: 'tsconfig.strict.json'     # Custom tsconfig path (default: tsconfig.json)
          strict-override: true                # Force strict mode (default: true)
          
          # Build options
          prebuild-command: 'yarn build:deps'  # Command to run before TSC (optional)
          prebuild-working-directory: '.'      # Prebuild working directory (default: .)
```

## Composite Actions

This package includes several composite actions that can be used independently:

### TypeScript Check (`./typescript`)

Run TypeScript compiler and count errors:

```yaml
- uses: thinkdx/ts-stricter/typescript@v2
  with:
    working-directory: '.'
    tsconfig: 'tsconfig.json'
    strict-override: true
    prebuild-command: ''
    prebuild-working-directory: '.'
```

### Dependency Installation (`./install`)

Install Node.js dependencies with caching:

```yaml
- uses: thinkdx/ts-stricter/install@v2
  with:
    package-manager: 'npm'
    working-directory: '.'
    cache-dependencies: true
    install-command: ''
    node-version: '18'
```

### Error Comparison (`./compare`)

Compare TypeScript error counts:

```yaml
- uses: thinkdx/ts-stricter/compare@v2
  with:
    head-errors: '10'
    base-errors: '12'
```

## Outputs

The main action provides the following outputs:

- `head-errors`: Number of TypeScript errors in HEAD
- `base-errors`: Number of TypeScript errors in BASE
- `error-difference`: Difference in error count (HEAD - BASE)
- `errors-increased`: Whether the error count increased

## Notes

1. **Pull Request Context**: This Action is specifically designed for **pull_request** events because it compares HEAD vs. BASE.
2. **TypeScript Configuration**: The action will use your repository's `tsconfig.json` by default, with the `--strict` flag enforced unless disabled.
3. **Caching**: Dependency caching is enabled by default to speed up workflows. Disable it with `cache-dependencies: false` if needed.
4. **Custom Commands**: Use `install-command` and `prebuild-command` to customize the workflow for complex setups.

## Contributing

Contributions and feedback are welcome! If you have new ideas or run into issues, please open a GitHub issue or submit a pull request to this repository.

## License

This project is licensed under the [MIT License](LICENSE). Feel free to modify and reuse in your own projects.