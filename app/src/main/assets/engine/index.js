'use strict';

/**
 * Anchor Engine — Main Entry Point
 *
 * The logger MUST be the first require so that every subsequent console call
 * (including those inside other modules during their own require-time
 * initialisation) is captured.
 */
require('./logger');

// ---------------------------------------------------------------------------
// Engine bootstrap
// ---------------------------------------------------------------------------
console.log('Anchor Engine starting on port 3160');

// TODO: Add nodejs-mobile integration and engine startup logic here.
