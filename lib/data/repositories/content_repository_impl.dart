import '../../domain/entities/agni_content.dart';
import '../../domain/repositories/content_repository.dart';
import '../datasources/local_content_data_source.dart';

class ContentRepositoryImpl implements ContentRepository {
  final LocalContentDataSource localDataSource;
  ContentRepositoryImpl(this.localDataSource);

  @override
  AgniContent getContent() => localDataSource.load();
}
