import '../config/tenant_config.dart';

String? resolveMediaUrl(TenantConfig config, String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  return '${config.apiBaseUrl.replaceAll(RegExp(r'/$'), '')}$path';
}
