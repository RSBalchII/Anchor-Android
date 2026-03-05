'use strict';

/**
 * Verbose Logger for Anchor Engine (Android)
 *
 * Intercepts console.log, console.error, and console.warn and appends all
 * output — with ISO-8601 timestamps — to the log file at:
 *   /storage/emulated/0/Download/anchor_engine_verbose.log
 *
 * The path is fixed per the Android deployment requirement. The app must hold
 * WRITE_EXTERNAL_STORAGE permission (or use a MediaStore URI on API 29+).
 *
 * Uses only the built-in `fs` module so it works inside the nodejs-mobile
 * binary without any npm dependencies.
 *
 * Call require('./logger') at the very top of index.js — the overrides take
 * effect synchronously and every subsequent console call is captured.
 */

const fs = require('fs');

const LOG_PATH = '/storage/emulated/0/Download/anchor_engine_verbose.log';

// ---------------------------------------------------------------------------
// Async write stream — opened in append mode so existing log content is kept.
// The stream handles its own internal buffer so writes are non-blocking and
// message order is always preserved.
// ---------------------------------------------------------------------------
let _stream = null;

function getStream() {
  if (!_stream) {
    try {
      _stream = fs.createWriteStream(LOG_PATH, { flags: 'a', encoding: 'utf8' });
      _stream.on('error', function () {
        // Silence stream errors so a disk/permission failure cannot crash the
        // engine. Recreate the stream on the next write attempt.
        _stream = null;
      });
    } catch (_) {
      return null;
    }
  }
  return _stream;
}

/**
 * Format a single argument for log output.
 *
 * @param {*} a
 * @returns {string}
 */
function formatArg(a) {
  if (a instanceof Error) {
    return a.stack || String(a);
  }
  if (typeof a === 'object' && a !== null) {
    try {
      return JSON.stringify(a);
    } catch (_) {
      return String(a);
    }
  }
  return String(a);
}

/**
 * Append a single line to the log file asynchronously.
 * Write errors are silently swallowed so a disk/permission failure can never
 * crash the engine.
 *
 * @param {string} level  - Log level label (LOG | ERROR | WARN)
 * @param {Array}  args   - Arguments passed to the original console method
 */
function appendToLog(level, args) {
  var stream = getStream();
  if (!stream) return;

  var timestamp = new Date().toISOString();
  var message = Array.prototype.map.call(args, formatArg).join(' ');
  var line = '[' + timestamp + '] [' + level + '] ' + message + '\n';

  stream.write(line);
}

// ---------------------------------------------------------------------------
// Preserve originals so the engine can still emit output to stdout/stderr
// when running in debug contexts (e.g. adb logcat).
// ---------------------------------------------------------------------------
const _originalLog   = console.log.bind(console);
const _originalError = console.error.bind(console);
const _originalWarn  = console.warn.bind(console);

console.log = function () {
  var args = Array.prototype.slice.call(arguments);
  appendToLog('LOG', args);
  _originalLog.apply(null, args);
};

console.error = function () {
  var args = Array.prototype.slice.call(arguments);
  appendToLog('ERROR', args);
  _originalError.apply(null, args);
};

console.warn = function () {
  var args = Array.prototype.slice.call(arguments);
  appendToLog('WARN', args);
  _originalWarn.apply(null, args);
};

// ---------------------------------------------------------------------------
// Write an initialization marker so the log clearly shows when the engine
// started (and the logger was loaded).
// ---------------------------------------------------------------------------
appendToLog('LOG', ['Anchor Engine logger initialized — verbose logging active']);

module.exports = { appendToLog };
