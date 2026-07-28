const js = require('@eslint/js');
const globals = require('globals');
const react = require('eslint-plugin-react');
const reactHooks = require('eslint-plugin-react-hooks');
const prettierConfig = require('eslint-config-prettier');
const tseslint = require('typescript-eslint');

const jsxFileGlobs = ['**/*.{js,jsx,ts,tsx}'];
const tsFileGlobs = ['**/*.{ts,tsx}'];

const sharedRules = {
  'no-console': 'warn',
  'no-var': 'error',
  'prefer-const': 'error',
  eqeqeq: ['error', 'always'],
  'react/prop-types': 'off',
  'react/react-in-jsx-scope': 'off',
  'react/jsx-uses-react': 'off',
  'react-hooks/rules-of-hooks': 'error',
  'react-hooks/exhaustive-deps': 'warn',
  'jsx-quotes': ['error', 'prefer-double'],
  quotes: ['error', 'single', { avoidEscape: true }],
  semi: ['error', 'always'],
};

module.exports = [
  {
    ignores: [
      'node_modules/**',
      'build/**',
      'dist/**',
      'out/**',
      'coverage/**',
      'storybook-static/**',
      '**/*.min.js',
      '**/*.min.css',
    ],
  },
  js.configs.recommended,
  react.configs.flat.recommended,
  react.configs.flat['jsx-runtime'],
  {
    files: jsxFileGlobs,
    plugins: {
      react,
      'react-hooks': reactHooks,
    },
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      parserOptions: {
        ecmaFeatures: { jsx: true },
      },
      globals: {
        ...globals.browser,
        ...globals.jest,
        ...globals['shared-node-browser'],
        process: 'readonly',
      },
    },
    settings: {
      react: { version: '19.2.4' },
    },
    rules: {
      ...sharedRules,
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
    },
  },
  ...tseslint.configs.recommended.map((config) => ({
    ...config,
    files: tsFileGlobs,
  })),
  {
    files: tsFileGlobs,
    rules: {
      ...sharedRules,
      'no-unused-vars': 'off',
      '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/no-explicit-any': 'warn',
    },
  },
  {
    files: [
      '**/setupTests.js',
      '**/__tests__/**/*.{js,jsx,ts,tsx}',
      '**/*.test.{js,jsx,ts,tsx}',
    ],
    languageOptions: {
      globals: { ...globals.node },
    },
  },
  prettierConfig,
];
