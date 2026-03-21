#!/usr/bin/env node
'use strict';

const { spawn } = require('child_process');
const { existsSync, readFileSync, writeFileSync, mkdirSync } = require('fs');
const { join, resolve } = require('path');
const { parseArgs } = require('util');

// --- Argument Parsing ---

const VALID_PROVIDERS = ['codex', 'gemini'];
const VALID_MODES = ['review', 'architecture', 'security', 'brainstorm', 'general'];

function parseCliArgs() {
  const { values, positionals } = parseArgs({
    args: process.argv.slice(2),
    allowPositionals: true,
    options: {
      mode:    { type: 'string' },
      task:    { type: 'string' },
      files:   { type: 'string' },
      focus:   { type: 'string' },
      context: { type: 'string' },
      timeout: { type: 'string' },
      model:   { type: 'string' },
    }
  });

  const provider = (positionals[0] || '').toLowerCase();
  if (!VALID_PROVIDERS.includes(provider)) {
    die(`Invalid provider "${provider}". Expected: ${VALID_PROVIDERS.join(', ')}`);
  }

  const mode = (values.mode || '').toLowerCase();
  if (!VALID_MODES.includes(mode)) {
    die(`Invalid mode "${mode}". Expected: ${VALID_MODES.join(', ')}`);
  }

  if (!values.task) {
    die('Missing required --task flag.');
  }

  return {
    provider,
    mode,
    task: values.task,
    files: values.files ? values.files.split(',').map(f => f.trim()).filter(Boolean) : [],
    focus: values.focus || '',
    context: values.context || '',
    timeout: parseInt(values.timeout || '120', 10) * 1000,
    model: values.model || '',
  };
}

function die(msg) {
  process.stderr.write(`[ccg] Error: ${msg}\n`);
  process.stderr.write('Usage: node ccg-compose.js <codex|gemini> --mode <mode> --task "<task>" [--files "<f1,f2>"] [--focus "<focus>"] [--context "<ctx>"] [--timeout <secs>] [--model <model>]\n');
  process.exit(1);
}

// --- Signal Handling ---
process.on('SIGINT', () => process.exit(130));
process.on('SIGTERM', () => process.exit(143));
