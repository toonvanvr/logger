/// Connection state and configuration for a server connection.
library;

/// Connection state for a server connection.
enum ServerConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// A server connection configuration and state.
class ServerConnection {
  final String id;
  final String url;
  final String? label;
  final bool enabled;
  final bool autoReconnect;
  final int colorIndex;
  final ServerConnectionState state;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;

  ServerConnection({
    required this.id,
    required this.url,
    this.label,
    this.enabled = true,
    this.autoReconnect = true,
    this.colorIndex = 0,
    this.state = ServerConnectionState.disconnected,
    this.retryCount = 0,
    this.lastError,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Display label: user label or extracted host from URL.
  String get displayLabel {
    if (label != null && label!.isNotEmpty) return label!;
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }

  /// Whether the connection is currently active.
  bool get isActive => state == ServerConnectionState.connected;

  /// Create a copy with the given fields replaced.
  ServerConnection copyWith({
    String? id,
    String? url,
    String? label,
    bool? enabled,
    bool? autoReconnect,
    int? colorIndex,
    ServerConnectionState? state,
    int? retryCount,
    String? lastError,
    DateTime? createdAt,
  }) {
    return ServerConnection(
      id: id ?? this.id,
      url: url ?? this.url,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      colorIndex: colorIndex ?? this.colorIndex,
      state: state ?? this.state,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
