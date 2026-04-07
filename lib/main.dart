import 'package:flutter/material.dart';

import 'data/datasources/local_content_data_source.dart';
import 'data/repositories/content_repository_impl.dart';
import 'domain/usecases/get_agni_content.dart';
import 'presentation/app/agni_app.dart';

void main() {
  final content = GetAgniContent(
    ContentRepositoryImpl(LocalContentDataSource()),
  )();
  runApp(AgniApp(content: content));
}
