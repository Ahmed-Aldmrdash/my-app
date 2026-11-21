import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/utils/ids.dart';

void main() {
  test('ids are unique and work on every platform', () {
    final ids = {for (var i = 0; i < 2000; i++) newId()};
    expect(ids, hasLength(2000));
    expect(ids.every((id) => id.length >= 8), isTrue);
  });
}
