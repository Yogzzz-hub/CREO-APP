class ApiEndpoints {
  // Production Cloudflare Edge Worker & FastAPI backend URL
  static const String defaultBaseUrl = 'https://creo-api-singapore.onrender.com';
  static const String workerProxyUrl = 'https://creo.yogalakshmibaskar20.workers.dev/api/v1';

  // Auth & Session
  static const String login = '/auth/login';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String me = '/auth/me';
  static const String refresh = '/auth/refresh';

  // Client Portal Core
  static const String portalDashboard = '/api/v1/portal/dashboard';
  static const String portalProfile = '/api/v1/portal/profile';
  static const String brandDna = '/api/v1/portal/brand-dna';
  static const String podInfo = '/api/v1/portal/pod';

  // Deliverables & Review
  static const String deliverables = '/api/v1/portal/deliverables';
  static String deliverableApprove(String id) => '/api/v1/deliverables/$id/approve';
  static String deliverableReject(String id) => '/api/v1/deliverables/$id/request-changes';
  static String deliverableVoiceNote(String id) => '/api/v1/deliverables/$id/upload-voice-note';
  static String deliverableVersions(String id) => '/api/v1/deliverables/$id/versions';

  // Content Calendar
  static const String calendarEntries = '/api/v1/calendar/entries';
  static const String calendarApprove30Day = '/api/v1/calendar/approve';
  static String approveHook(String slotId) => '/api/v1/calendar/slots/$slotId/approve-concept';
  static String rerollHook(String slotId) => '/api/v1/calendar/slots/$slotId/reroll-concept';

  // Payments & Subscription
  static const String subscription = '/api/v1/payments/subscription';
  static const String splitSummary = '/api/v1/payments/split-summary';
  static const String createOrder = '/api/v1/payments/orders';

  // Support Tickets
  static const String tickets = '/api/v1/tickets';
  static String ticketMessages(String id) => '/api/v1/tickets/$id/messages';

  // Chat WebSocket
  static String chatWebSocket(String userId) => 'wss://creo-api-singapore.onrender.com/api/v1/chat/ws/$userId';
}

