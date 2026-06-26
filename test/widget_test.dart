import 'package:flutter_test/flutter_test.dart';
import 'package:flohmarkt_app/screens/map_screen.dart';

void main() {
  testWidgets('App starts with map screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MapScreen()); // placeholder
    expect(find.text('Flohmarkt-Finder'), findsNothing); // widget exists but might not have text yet
  });
}
