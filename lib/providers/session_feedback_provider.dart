import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/session_feedback_service.dart';

final sessionFeedbackServiceProvider = Provider<SessionFeedbackService>((ref) {
  return SessionFeedbackService();
});
