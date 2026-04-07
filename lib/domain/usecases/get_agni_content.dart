import '../entities/agni_content.dart';
import '../repositories/content_repository.dart';

class GetAgniContent {
  final ContentRepository repository;
  const GetAgniContent(this.repository);

  AgniContent call() => repository.getContent();
}
