// Package "a": 2 strict-mode errors, clean under strict: false.

// noImplicitAny
export function double(x) {
  return x * 2;
}

// strictNullChecks
const maybe: number | null = (Math.random() > 0.5 ? 1 : null) as number | null;
export const next = maybe + 1;
