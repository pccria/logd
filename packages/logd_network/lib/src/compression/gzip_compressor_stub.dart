/// Stub implementation for non-IO platforms (e.g., Web, WASM).
library;

/// Compresses [bytes] using GZip. Returns `null` on unsupported platforms.
List<int>? gzipCompress(final List<int> bytes) => null;

/// Indicates whether GZip compression is supported in this runtime environment.
const bool isGzipSupported = false;
