import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/referral_model.dart';

/// Thông tin giới thiệu của tài xế — autoDispose để mở lại màn là nạp mới.
final referralProvider = FutureProvider.autoDispose<ReferralInfo>((ref) async {
  final res = await ref.read(apiClientProvider).get('/driver/referral');
  final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;
  return ReferralInfo.fromJson(data);
});
