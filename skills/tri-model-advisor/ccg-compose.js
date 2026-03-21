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

// --- Sanitization ---

function sanitizeContent(content, maxLength = 4000) {
  if (!content) return '';
  let s = content.length > maxLength ? content.slice(0, maxLength) : content;

  // Fix dangling surrogate pairs
  if (s.length > 0) {
    const lastCode = s.charCodeAt(s.length - 1);
    if (lastCode >= 0xD800 && lastCode <= 0xDBFF) {
      s = s.slice(0, -1);
    }
  }

  // Escape XML-like delimiter tags that could break prompt structure
  s = s.replace(/<(\/?)(system-instructions)[^>]*>/gi, '[$1$2]');
  s = s.replace(/<(\/?)(SYSTEM)[^>]*>/gi, '[$1$2]');
  s = s.replace(/<(\/?)(INSTRUCTIONS)[^>]*>/gi, '[$1$2]');

  // Escape untrusted file content delimiters
  s = s.replace(/^-{3}\s*(UNTRUSTED FILE CONTENT|END UNTRUSTED FILE CONTENT)/gm, '[-- $1');

  return s;
}

function sanitizeFilepath(filepath) {
  return filepath.replace(/[\n\r]/g, '').replace(/-{3}/g, '\u2014');
}

function wrapUntrustedFile(filepath, content) {
  const safePath = sanitizeFilepath(filepath);
  const sanitized = sanitizeContent(content);
  return `--- UNTRUSTED FILE CONTENT (${safePath}) ---\n${sanitized}\n--- END UNTRUSTED FILE CONTENT ---`;
}
