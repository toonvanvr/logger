import '../services/connection_manager.dart';

/// Handles `logger://` URI scheme for deep-link operations.
///
/// Supported URIs:
/// - `logger://open` — Focus/open the app (no-op, app is already open)
/// - `logger://connect?host=<host>&port=<port>` — Add a server connection
/// - `logger://filter?query=<query>` — Set a text filter
/// - `logger://tab?name=<name>` — Switch to a section tab by name
/// - `logger://clear` — Clear all filters
class UriHandler {
  /// Parse and handle a `logger://` URI string.
  ///
  /// Returns `true` if the URI was recognized and handled, `false` otherwise.
  static bool handleUri(
    String uriString, {
    required ConnectionManager connectionManager,
    required void Function(String) onFilter,
    required void Function(String) onTab,
    required void Function() onClear,
  }) {
    final parsed = Uri.tryParse(uriString);
    if (parsed == null || parsed.scheme != 'logger') return false;

    switch (parsed.host) {
      case 'open':
        // App is already open — no action needed.
        return true;

      case 'connect':
        final host = parsed.queryParameters['host'] ?? 'localhost';
        final port =
            int.tryParse(parsed.queryParameters['port'] ?? '8080') ?? 8080;
        final url = 'ws://$host:$port/api/v2/stream';
        connectionManager.addConnection(url, label: '$host:$port');
        return true;

      case 'filter':
        final query = parsed.queryParameters['query'] ?? '';
        onFilter(query);
        return true;

      case 'tab':
        final name = parsed.queryParameters['name'] ?? '';
        onTab(name);
        return true;

      case 'clear':
        onClear();
        return true;

      default:
        return false;
    }
  }

  /// Extract the first `logger://` URI from a list of command-line arguments.
  ///
  /// Returns `null` if no matching argument is found.
  static String? extractFromArgs(List<String> args) {
    for (final arg in args) {
      if (arg.startsWith('logger://')) return arg;
    }
    return null;
  }
}
