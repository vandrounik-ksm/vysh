/// Один JSON-документ конфигурации (hosts.json, settings.json, …).
/// Реализация по умолчанию - файл в папке профиля (`infra/storage`).
abstract interface class DocumentStore {
  /// Содержимое документа; null - документа нет или его не удалось прочитать.
  Object? readSync();

  /// Записать документ. Future завершается после фактической записи;
  /// false - запись не удалась (ошибку реализация показывает сама).
  Future<bool> write(Object? data);
}
