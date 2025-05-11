// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import the HomePage widget from the home.dart file
import 'package:assignment_test/screen/home.dart';
// You likely don't need to import main.dart directly in most widget tests
// import 'package:assignment_test/main.dart';


void main() {
  // The default counter increment test is not relevant to our HomePage.
  // You should replace this with tests specific to your application's widgets.
  /*
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(HomePage()); // Now HomePage should be recognized

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
  */

  // Example of a relevant test for the HomePage:
  testWidgets('HomePage displays Search Bar hint text', (WidgetTester tester) async {
    // Build the HomePage widget
    await tester.pumpWidget(MaterialApp( // Wrap HomePage in MaterialApp for context
      home: HomePage(),
    ));

    // Verify that the hint text "Search challenges..." is displayed
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search challenges...'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);

    // You can add more tests here to check other elements on the HomePage,
    // like titles, specific text widgets, buttons, etc.
  });

}