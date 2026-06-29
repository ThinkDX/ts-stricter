// This fixture is clean with `strict: false` but produces exactly 2 errors
// under `--strict`. The test runner asserts both counts, proving that
// ts-stricter's strict enforcement actually changes what tsc reports.

// 1) noImplicitAny: parameter `name` implicitly has type `any`.
export function greet(name) {
  return `Hello, ${name.toUpperCase()}`;
}

// 2) strictNullChecks: `value` is possibly null.
const value: string | null = (Math.random() > 0.5 ? "x" : null) as string | null;
export const length = value.length;
