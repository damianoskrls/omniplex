import 'package:flutter_test/flutter_test.dart';
import 'package:bookup_app/config/tenant_config.dart';

void main() {
  test('TenantConfig parses sample config', () {
    final config = TenantConfig.fromJson({
      'business_id': 'test-id',
      'slug': 'test',
      'app_name': 'Test App',
      'bundle_id': 'com.bookup.test',
      'api_base_url': 'http://localhost:3001',
      'primary_color': '#6200EE',
      'secondary_color': '#03DAC6',
      'accent_color': '#FF6D00',
      'feature_online_booking': 1,
      'feature_loyalty_points': 0,
      'feature_memberships': 1,
      'label_overrides': {'book_cta': 'Book'},
    });

    expect(config.businessId, 'test-id');
    expect(config.appName, 'Test App');
    expect(config.featureOnlineBooking, isTrue);
    expect(config.label('book_cta', 'fallback'), 'Book');
  });
}
