import 'package:flutter_test/flutter_test.dart';

import 'package:agni_landing/data/datasources/local_content_data_source.dart';
import 'package:agni_landing/data/repositories/content_repository_impl.dart';
import 'package:agni_landing/domain/usecases/get_agni_content.dart';
import 'package:agni_landing/presentation/app/agni_app.dart';

void main() {
  testWidgets('Technodysis landing renders hero', (tester) async {
    final content = GetAgniContent(
      ContentRepositoryImpl(LocalContentDataSource()),
    )();

    await tester.pumpWidget(AgniApp(content: content));

    expect(find.text('Agentic AI + Automation'), findsOneWidget);
  });
}
