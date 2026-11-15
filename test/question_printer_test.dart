import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodCall, MethodChannel, PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/question_pdf.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/models/question_print_settings.dart';
import 'package:mirsam/domain/services/question_print_plan.dart';
import 'package:pdf/pdf.dart';

import 'test_support.dart';

const _printingChannel = MethodChannel('net.nfet.printing');

/// Simulate an Android/Windows plugin callback over the real method channel.
Future<Object?> _sendPrintingCallback(String method, Map<String, Object?> arguments) async {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final reply = await messenger.handlePlatformMessage(
    _printingChannel.name,
    _printingChannel.codec.encodeMethodCall(MethodCall(method, arguments)),
    null,
  );
  if (reply == null) {
    throw StateError('The printing plugin did not handle $method');
  }
  return _printingChannel.codec.decodeEnvelope(reply);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sends the same A4 PDF to the print dialog on repeated layout callbacks', () async {
    final library = await ensureLibrary();
    final unit = library.unitsOf('g1').first;
    final plan = QuestionPrintPlan.fromSelection(
      <LearningUnit>[unit],
      <String>{unit.id},
      settings: const QuestionPrintSettings(
        font: QuestionPrintFont.amiri,
        bodyFontSize: 18,
        headingFontSize: 24,
      ),
    );
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(_printingChannel, null));
    Map<dynamic, dynamic>? request;
    final documents = <Uint8List>[];
    messenger.setMockMethodCallHandler(_printingChannel, (call) async {
      expect(call.method, 'printPdf');
      request = call.arguments as Map<dynamic, dynamic>;
      for (final format in <PdfPageFormat>[PdfPageFormat.a4, PdfPageFormat.letter]) {
        final data = await _sendPrintingCallback('onLayout', <String, Object?>{
          'job': request!['job'],
          'width': format.width,
          'height': format.height,
          'marginLeft': format.marginLeft,
          'marginTop': format.marginTop,
          'marginRight': format.marginRight,
          'marginBottom': format.marginBottom,
        });
        documents.add(data as Uint8List);
      }
      await _sendPrintingCallback('onCompleted', <String, Object?>{
        'job': request!['job'],
        'completed': true,
      });
      return 1;
    });

    await QuestionPrinter.print(plan, unit.grade);
    expect(request!['name'], 'mirsam-questions.pdf');
    expect(request!['width'], closeTo(PdfPageFormat.a4.width, 0.001));
    expect(request!['height'], closeTo(PdfPageFormat.a4.height, 0.001));
    expect(request!['dynamic'], isFalse);
    expect(documents, hasLength(2));
    expect(latin1.decode(documents.first.take(5).toList()), '%PDF-');
    expect(documents.last, orderedEquals(documents.first));
  });

  test('propagates a failure to open the platform print dialog', () async {
    final library = await ensureLibrary();
    final unit = library.unitsOf('g1').first;
    final plan = QuestionPrintPlan.fromSelection(<LearningUnit>[unit], <String>{unit.id});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(_printingChannel, null));
    messenger.setMockMethodCallHandler(_printingChannel, (call) async {
      throw PlatformException(code: 'printer-unavailable');
    });

    await expectLater(QuestionPrinter.print(plan, unit.grade), throwsA(isA<PlatformException>()));
  });
}
