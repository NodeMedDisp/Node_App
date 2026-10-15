import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/GetStarted/enter_counseling_data.dart';
import '../lib/models/counseling_question.dart';

class EditResult {
  CounselingQuestion? value;
}

Future<EditResult> openEditor(WidgetTester tester, CounselingQuestion original) async {
  final result = EditResult();
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      home: Builder(builder: (context) => Scaffold(
        body: TextButton(
          child: const Text('Open editor'),
          onPressed: () async {
            result.value = await Navigator.push<CounselingQuestion>(
              context,
              MaterialPageRoute(builder: (_) => EnterCounselingPrompts(
                medications: const [], initialPrompt: original, returnResultOnly: true,
              )),
            );
          },
        ),
      )),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
  return result;
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('prompt-save')));
  await tester.tap(find.byKey(const ValueKey('prompt-save')));
  await tester.pumpAndSettle();
}

CounselingQuestion example() => CounselingQuestion(
  id: 'existing-id', prompt: 'Original prompt', resReq: 'Yes',
  options: const ['Yes', 'No'], startDate: DateTime(2026, 10, 10), numberOfDays: 3,
  streakEnabled: true, streakTitle: 'Original streak', streakThreshold: 'No',
  tokenEnabled: true, tokenTitle: 'Original token', tokenThreshold: 'Yes', tokenQuantity: 2,
);

void main() {
  testWidgets('editing text and duration retains ID, date, response, and rewards', (tester) async {
    final original = example();
    final result = await openEditor(tester, original);
    await tester.enterText(find.byKey(const ValueKey('prompt-text')), 'Edited prompt');
    await tester.ensureVisible(find.byKey(const ValueKey('prompt-days')));
    await tester.enterText(find.byKey(const ValueKey('prompt-days')), '7');
    await save(tester);
    expect(result.value, isNotNull);
    expect(result.value!.id, original.id);
    expect(result.value!.prompt, 'Edited prompt');
    expect(result.value!.numberOfDays, 7);
    expect(result.value!.startDate, original.startDate);
    expect(result.value!.options, original.options);
    expect(result.value!.streakTitle, original.streakTitle);
    expect(result.value!.streakThreshold, original.streakThreshold);
    expect(result.value!.tokenThreshold, original.tokenThreshold);
    expect(result.value!.tokenQuantity, original.tokenQuantity);
    expect(original.prompt, 'Original prompt');
  });

  testWidgets('start date can be selected independently of duration', (tester) async {
    final result = await openEditor(tester, example());
    await tester.ensureVisible(find.byKey(const ValueKey('prompt-start')));
    await tester.tap(find.byKey(const ValueKey('prompt-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(result.value!.startDate, DateTime(2026, 10, 15));
    expect(result.value!.numberOfDays, 3);
  });

  testWidgets('invalid duration does not save an edit', (tester) async {
    final result = await openEditor(tester, example());
    await tester.ensureVisible(find.byKey(const ValueKey('prompt-days')));
    await tester.enterText(find.byKey(const ValueKey('prompt-days')), '0');
    await save(tester);
    expect(result.value, isNull);
    expect(find.text('Enter a valid number of days.'), findsOneWidget);
  });

  testWidgets('legacy number response loads without changing its encoding', (tester) async {
    final original = example().copyWith(
      resReq: 'number', options: [], streakThreshold: '<=5', tokenThreshold: '>3',
    );
    final result = await openEditor(tester, original);
    expect(tester.takeException(), isNull);
    await save(tester);
    expect(result.value!.resReq, 'number');
    expect(result.value!.options, isEmpty);
    expect(result.value!.streakThreshold, '<=5');
    expect(result.value!.tokenThreshold, '>3');
  });

  testWidgets('legacy yes_no can be edited without replacing options', (tester) async {
    final original = example().copyWith(resReq: 'yes_no', options: []);
    final result = await openEditor(tester, original);
    await save(tester);
    expect(result.value!.resReq, 'yes_no');
    expect(result.value!.options, isEmpty);
  });

  testWidgets('custom response options survive unrelated edits', (tester) async {
    final original = example().copyWith(resReq: 'custom', options: ['Low', 'Medium', 'High']);
    final result = await openEditor(tester, original);
    await tester.enterText(find.byKey(const ValueKey('prompt-text')), 'Changed text');
    await save(tester);
    expect(result.value!.resReq, 'custom');
    expect(result.value!.options, ['Low', 'Medium', 'High']);
    expect(result.value!.tokenThreshold, original.tokenThreshold);
  });

  testWidgets('back navigation cancels without modifying the original', (tester) async {
    final original = example();
    final result = await openEditor(tester, original);
    await tester.enterText(find.byKey(const ValueKey('prompt-text')), 'Not saved');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(result.value, isNull);
    expect(original.prompt, 'Original prompt');
  });
}
