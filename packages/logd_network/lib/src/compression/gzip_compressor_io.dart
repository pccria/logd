/// Native VM implementation of GZip compression using `dart:io`.
library;

import 'dart:io';

/// Compresses [bytes] using GZip.
List<int>? gzipCompress(final List<int> bytes) => gzip.encode(bytes);

/// Indicates whether GZip compression is supported in this runtime environment.
const bool isGzipSupported = true;
