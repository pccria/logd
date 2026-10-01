/// HTML satellite package for logd.
///
/// Provides [HtmlEncoder], [HtmlFileHandler], and [HtmlStylesheet] for
/// generating rich, browser-friendly log documents.
library;

import 'package:logd/logd.dart';

import 'src/html_encoder.dart';
import 'src/html_file_handler.dart';
import 'src/html_formatter.dart';
import 'src/html_stylesheet.dart';

export 'src/html_encoder.dart';
export 'src/html_file_handler.dart';
export 'src/html_formatter.dart';
export 'src/html_stylesheet.dart';

/// Registers HTML components into logd's [LoggerSerializationRegistry].
///
/// Call this during isolate setup or app bootstrapping when using isolates or
/// custom serialization pipelines:
/// ```dart
/// registerLogdHtmlSerializers();
/// ```
void registerLogdHtmlSerializers() {
  LoggerSerializationRegistry.ensureInitialized();

  LoggerSerializationRegistry.registerFormatter<HtmlFormatter>(
    type: 'HtmlFormatter',
    fromJson: (final json) => HtmlFormatter(
      title: json['title'] as String? ?? 'Log Output',
      // Note: Custom stylesheets require manual registration if used across
      // isolates
      stylesheet: const DefaultHtmlStylesheet(),
    ),
    toJson: (final val) => <String, dynamic>{
      'title': val.title,
    },
  );
}
