// Conditionally export dart:js on web and the js_stub.dart on native platforms.
export 'js_stub.dart' if (dart.library.js) 'dart:js';
