/// Удержание приложения в фоне, пока есть живые SSH-сессии
/// (на Android - foreground-сервис с уведомлением; на ПК ничего не делает).
abstract interface class BackgroundSessions {
  /// Есть хотя бы одна подключённая или подключающаяся сессия.
  /// [title] - что показать в уведомлении.
  void active(String title);

  /// Живых сессий не осталось.
  void idle();
}
