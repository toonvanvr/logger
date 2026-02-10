/// Sub-model classes used by [LogEntry].
///
/// Contains [ApplicationInfo] and [ImageData]. Other sub-models are in
/// [exception_models.dart] and [data_state_models.dart].
library;

// ─── ApplicationInfo ─────────────────────────────────────────────────

class ApplicationInfo {
  final String name;
  final String? version;
  final String? environment;

  const ApplicationInfo({required this.name, this.version, this.environment});

  factory ApplicationInfo.fromJson(Map<String, dynamic> json) {
    return ApplicationInfo(
      name: json['name'] as String,
      version: json['version'] as String?,
      environment: json['environment'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (version != null) 'version': version,
    if (environment != null) 'environment': environment,
  };
}

// ─── ImageData ───────────────────────────────────────────────────────

class ImageData {
  final String? data;
  final String? ref;
  final String? mimeType;
  final String? label;
  final int? width;
  final int? height;

  const ImageData({
    this.data,
    this.ref,
    this.mimeType,
    this.label,
    this.width,
    this.height,
  });

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      data: json['data'] as String?,
      ref: json['ref'] as String?,
      mimeType: json['mimeType'] as String?,
      label: json['label'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (data != null) 'data': data,
    if (ref != null) 'ref': ref,
    if (mimeType != null) 'mimeType': mimeType,
    if (label != null) 'label': label,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
  };
}
