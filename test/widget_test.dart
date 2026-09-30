import 'package:flutter_test/flutter_test.dart';

import 'package:sabai_tourisme/utils/theme.dart';

void main() {
  test('le thème applique bien la couleur principale de la charte', () {
    final theme = buildAppTheme();
    expect(theme.colorScheme.primary, AppColors.primary);
  });
}
