class ApiConstants {
  // Base URLs — extracted from .env
  static const String baseUrl       = 'https://vtalanoa.com';
  static const String signalingUrl  = 'https://navuli-meet-signaling.onrender.com';

  // ── Auth (/api/auth/* — JWT issued on login/register) ──────────────────
  static const String login    = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String logout   = '/api/auth/logout';
  static const String me       = '/api/auth/me';

  // ── Meetings (/api/meetings/* — Bearer JWT required) ───────────────────
  static const String meetings = '/api/meetings';
  static String meeting(String token)       => '/api/meetings/$token';
  static String startMeeting(String token)  => '/api/meetings/$token/start';
  static String endMeeting(String token)    => '/api/meetings/$token/end';
  static String resolveMeeting(String token)=> '/api/meetings/resolve/$token';
  static String joinMeeting(String token)   => '/api/meetings/$token/join';
  static String meetingStats(String token)        => '/api/meetings/$token/stats';
  static String meetingParticipants(String token) => '/api/meetings/$token/participants';
  static String meetingFiles(String token)        => '/api/meetings/$token/files';

  // ── Chat (/api/chat/* — Bearer JWT required) ───────────────────────────
  static String chatMessages(String token) => '/api/chat/$token';
  static const String chatUpload           = '/api/chat/upload';

  // ── Cloudflare SFU proxy (server-side secret, JWT protected) ───────────
  // Routes: POST sessions/new, POST sessions/:sid/tracks/new,
  //         PUT  sessions/:sid/renegotiate, PUT sessions/:sid/tracks/close
  static String sfuProxy(String token) => '/api/meetings/$token/sfu-proxy';
}
