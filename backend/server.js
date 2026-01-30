/**
 * Root entry point for deployment environments (like Render)
 * that expect server.js to be in the root directory.
 * Requires the compiled output (dist/) since TypeScript compiles there.
 */
require('./dist/server.js');
