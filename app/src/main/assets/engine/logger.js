'use strict';

/**
 * Verbose Logger for Anchor Engine (Android)
 *
 * Intercepts console.log, console.error, and console.warn and appends all
 * output — with ISO-8601 timestamps — to the log file.
 *
 * Primary log path (requires MANAGE_EXTERNAL_STORAGE on API 30+):
 *   /storage/emulated/0/Download/anchor_engine_verbose.log
 *
 * Fallback log path (app-scoped external storage, no special permission needed):
 *   /sdcard/Android/data/org.anchoros.android/files/anchor_engine_verbose.log
 *
 * If the primary path cannot be opened or written (e.g. MANAGE_EXTERNAL_STORAGE
 * has not yet been granted by the user), the logger automatically retries using
 * the fallback path so that engine output is never silently discarded.
 *
 * Uses only the built-in `fs` module so it works inside the nodejs-mobile
 * binary without any npm dependencies.
 *
 * Call require('./logger') at the very top of index.js — the overrides take
 * effect synchronously and every subsequent console call is captured.
 */

const fs = require('fs');

// Primary log path: public Downloads folder (requires MANAGE_EXTERNAL_STORAGE on API 30+).
// Fallback log path: app-scoped external storage (no special permission needed).
const LOG_PATH_PRIMARY  = '/storage/emulated/0/Download/anchor_engine_verbose.log';
const LOG_PATH_FALLBACK = '/sdcard/Android/data/org.anchoros.android/files/anchor_engine_verbose.log';

// ---------------------------------------------------------------------------
// Async write stream — opened in append mode so existing log content is kept.
// The stream handles its own internal buffer so writes are non-blocking and
// message order is always preserved.
// ---------------------------------------------------------------------------
let _stream           = null;
let _useFallback      = false;
let _permanentlyFailed = false;

function getStream() {
  if (_permanentlyFailed) return null;
  if (!_stream) {
    const logPath = _useFallback ? LOG_PATH_FALLBACK : LOG_PATH_PRIMARY;
    try {
      _stream = fs.createWriteStream(logPath, { flags: 'a', encoding: 'utf8' });
      _stream.on('error', function () {
        // If the primary path fails (e.g. MANAGE_EXTERNAL_STORAGE not granted),
        // switch to the app-scoped fallback path on the next write attempt.
        _stream = null;
        if (!_useFallback) {
          _useFallback = true;
        } else {
          // Both paths have failed — stop retrying to avoid busy loops.
          _permanentlyFailed = true;
        }
      });
    } catch (_) {
      if (!_useFallback) {
        _useFallback = true;
      } else {
        // Both paths have failed synchronously — give up.
        _permanentlyFailed = true;
      }
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
