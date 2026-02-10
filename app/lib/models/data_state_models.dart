/// Display and state model classes used by [LogEntry].
///
/// Contains [IconRef], [WidgetPayload], and [DataState].
library;

import 'log_enums.dart';

// ─── IconRef ─────────────────────────────────────────────────────────

class IconRef {
  final String icon;
  final String? color;
  final double? size;

  const IconRef({required this.icon, this.color, this.size});

  factory IconRef.fromJson(Map<String, dynamic> json) {
    return IconRef(
      icon: json['icon'] as String,
      color: json['color'] as String?,
      size: (json['size'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'icon': icon,
    if (color != null) 'color': color,
    if (size != null) 'size': size,
  };
}

// ─── WidgetPayload ───────────────────────────────────────────────────

class WidgetPayload {
  final String type;
  final Map<String, dynamic> data;

  const WidgetPayload({required this.type, required this.data});

  factory WidgetPayload.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final data = Map<String, dynamic>.from(json)..remove('type');
    return WidgetPayload(type: type, data: data);
  }

  Map<String, dynamic> toJson() => {'type': type, ...data};
}

// ─── DataState ───────────────────────────────────────────────────────

class DataState {
  final dynamic value;
  final List<dynamic>? history;
  final DisplayLocation display;
  final WidgetPayload? widget;
  final String? label;
  final IconRef? icon;
  final String? updatedAt;

  const DataState({
    required this.value,
    this.history,
    this.display = DisplayLocation.defaultLoc,
    this.widget,
    this.label,
    this.icon,
    this.updatedAt,
  });

  factory DataState.fromJson(Map<String, dynamic> json) {
    return DataState(
      value: json['value'],
      history: json['history'] as List<dynamic>?,
      display: parseDisplayLocation(json['display'] as String? ?? 'default'),
      widget: json['widget'] != null
          ? WidgetPayload.fromJson(json['widget'] as Map<String, dynamic>)
          : null,
      label: json['label'] as String?,
      icon: json['icon'] != null
          ? IconRef.fromJson(json['icon'] as Map<String, dynamic>)
          : null,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    if (history != null) 'history': history,
    'display': switch (display) {
      DisplayLocation.defaultLoc => 'default',
      DisplayLocation.static_ => 'static',
      DisplayLocation.shelf => 'shelf',
    },
    if (widget != null) 'widget': widget!.toJson(),
    if (label != null) 'label': label,
    if (icon != null) 'icon': icon!.toJson(),
    if (updatedAt != null) 'updated_at': updatedAt,
  };
}
