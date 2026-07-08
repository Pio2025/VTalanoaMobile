import 'package:flutter/foundation.dart';

/// Temporary, verbose debug logging for the join / socket / WebRTC flows.
///
/// Intentionally simple (just `debugPrint`, no log level filtering) so every
/// call site is a one-line `grep -rn "vtLog("` away from deletion once these
/// flows are confirmed stable in production.
void vtLog(String tag, String message) {
  debugPrint('[VT:$tag] $message');
}
