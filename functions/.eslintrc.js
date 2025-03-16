module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    'eslint:recommended',
  ],
  rules: {
    'no-unused-vars': 'warn',
    indent: ['error', 2],
    'max-len': ['error', { code: 120 }],
    quotes: ['error', 'single', { allowTemplateLiterals: true }],
  },
  parserOptions: {
    ecmaVersion: 2020,
  },
  overrides: [
    {
      files: ['**/*.spec.*'],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
