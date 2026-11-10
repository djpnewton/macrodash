import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrodash/option_buttons.dart';
import 'package:macrodash/theme.dart';

enum _Choices { one, twoThree }

Future<void> _pumpOptions(
  WidgetTester tester, {
  _Choices selected = _Choices.one,
  bool popout = false,
  required void Function(_Choices) onOptionSelected,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: OptionButtons<_Choices>(
        popoutTitle: 'Choice',
        selectedOption: selected,
        values: _Choices.values,
        onOptionSelected: onOptionSelected,
        labels: const {_Choices.one: 'One'},
        popout: popout,
      ),
    ),
  ),
);

OptionButton _button(WidgetTester tester, String label) =>
    tester.widget<OptionButton>(find.widgetWithText(OptionButton, label));

void main() {
  testWidgets('renders a button per value, labelled or upper cased', (
    tester,
  ) async {
    await _pumpOptions(tester, onOptionSelected: (_) {});

    expect(find.byType(OptionButton), findsNWidgets(2));
    expect(find.text('One'), findsOneWidget);
    expect(find.text('TWOTHREE'), findsOneWidget);
  });

  testWidgets('only the selected value is highlighted', (tester) async {
    await _pumpOptions(tester, onOptionSelected: (_) {});

    expect(_button(tester, 'One').isSelected, isTrue);
    expect(_button(tester, 'TWOTHREE').isSelected, isFalse);

    await _pumpOptions(
      tester,
      selected: _Choices.twoThree,
      onOptionSelected: (_) {},
    );

    expect(_button(tester, 'One').isSelected, isFalse);
    expect(_button(tester, 'TWOTHREE').isSelected, isTrue);
  });

  testWidgets('reports the tapped value', (tester) async {
    final selected = <_Choices>[];
    await _pumpOptions(tester, onOptionSelected: selected.add);

    await tester.tap(find.text('TWOTHREE'));
    await tester.pump();

    expect(selected, [_Choices.twoThree]);
  });

  testWidgets('popout shows the selection and picks from a dialog', (
    tester,
  ) async {
    final selected = <_Choices>[];
    await _pumpOptions(tester, popout: true, onOptionSelected: selected.add);

    // Collapsed to the current value only.
    expect(find.byType(OptionButton), findsOneWidget);
    expect(find.text('Choice:'), findsOneWidget);
    expect(_button(tester, 'One').isSelected, isTrue);

    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();

    expect(find.text('Select Choice'), findsOneWidget);
    expect(find.byType(OptionButton), findsNWidgets(3));

    await tester.tap(find.text('TWOTHREE').last);
    await tester.pumpAndSettle();

    expect(find.text('Select Choice'), findsNothing);
    expect(selected, [_Choices.twoThree]);
  });
}
