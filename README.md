# TS Stricter

This GitHub Action helps you **iteratively migrate** your **unstrict** TypeScript codebase to a **strict** one. It does this by **comparing the TypeScript error count** on your pull request’s **HEAD** branch vs. the **BASE** branch and **fails** the workflow if new errors have been introduced.  

By ensuring that your error count never goes up, your team can gradually reduce existing errors over time—eventually reaching a fully strict codebase without sudden disruptions.

---

## How It Works

1. **Checkout** and run `tsc` on the **HEAD** branch (the PR branch).
2. **Extract** the number of errors from the compiler output.
3. **Checkout** the **BASE** branch and run `tsc` again.
4. **Compare** the two error counts and **fail** the workflow if the HEAD error count is greater.

This approach enforces a “**no new errors**” policy, allowing teams to **chip away** at TypeScript errors and strictness violations without overwhelming developers.

---

## Usage

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
        uses: thinkdx/ts-stricter@v1
```

### Notes

1. **Pull Request Context**: This Action is specifically designed for **pull_request** events because it compares HEAD vs. BASE.
2. **Node Setup**: If you need a different Node version or have a custom install step, place those steps **before** calling the Action.
3. **Permissions**: Ensure the workflow has sufficient permissions for checking out and reading the repository.
4. **tsconfig**: Make sure your repository has a `tsconfig.json` that `tsc` can recognize.  
5. **No Additional Errors**: If the PR introduces new TypeScript errors, the Action will fail, helping maintain or reduce your overall error count.

---

## Why Use This Action?

- **Iterative Strictness**: Incrementally refactor your codebase to stricter TypeScript settings without a large one-time lift.
- **Prevent Regression**: Ensure new pull requests don’t introduce additional errors, keeping your journey to strictness on track.
- **Simple Integration**: Add a single workflow step that automatically checks and enforces your error budget.

---

## Contributing

Contributions and feedback are welcome! If you have new ideas or run into issues, please open a GitHub issue or submit a pull request to this repository.

---

## License

This project is licensed under the [MIT License](LICENSE). Feel free to modify and reuse in your own projects.