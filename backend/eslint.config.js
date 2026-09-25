// @ts-check
import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    // scripts/ holds one-off, non-application utility scripts (e.g. a
    // browser-console snippet for the Supabase dashboard) — not part of
    // the TS backend this ticket's lint gate is scoped to.
    ignores: ['dist/**', 'node_modules/**', 'legacy/**', 'coverage/**', 'scripts/**'],
  },
  {
    files: ['src/**/*.ts', 'tests/**/*.ts'],
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    rules: {
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
    },
  },
);
