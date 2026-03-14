import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    reporters: process.env.CI ? ['default', 'junit'] : ['default'],
    outputFile: process.env.CI ? { junit: 'test-results/junit.xml' } : undefined,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      include: ['src/domain/**/*.ts', 'src/application/**/*.ts'],
      exclude: [
        'src/main.ts',
        '**/*.test.ts',
        '**/uat-helpers.ts',
        '**/node_modules/**',
        'src/domain/meal.ts',
        'src/domain/diet-rules.ts',
      ],
      thresholds: {
        lines: 100,
        functions: 100,
        branches: 90,
        statements: 100,
      },
    },
  },
});
