import 'package:flutter_test/flutter_test.dart';
import 'package:ringtask/utils/task_parser.dart';

void main() {
  group('TaskParser Tests', () {
    test('Parse basic task without date', () {
      final result = TaskParser.parseVoiceInput('Buy groceries');
      expect(result.title, 'Buy groceries');
      expect(result.dateTime, isNull);
    });

    test('Parse task with tomorrow', () {
      final result = TaskParser.parseVoiceInput('Call mom tomorrow');
      expect(result.title, 'Call mom');
      expect(result.dateTime, isNotNull);
      
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(result.dateTime!.day, tomorrow.day);
      expect(result.dateTime!.month, tomorrow.month);
    });

    test('Parse task with specific time', () {
      final result = TaskParser.parseVoiceInput('Meeting at 5pm');
      expect(result.title, 'Meeting');
      expect(result.dateTime, isNotNull);
      expect(result.dateTime!.hour, 17);
      expect(result.dateTime!.minute, 0);
    });

    test('Parse task with tomorrow and time', () {
      final result = TaskParser.parseVoiceInput('Go to gym tomorrow at 9:30 am');
      expect(result.title, 'Go to gym');
      expect(result.dateTime, isNotNull);
      
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(result.dateTime!.day, tomorrow.day);
      expect(result.dateTime!.hour, 9);
      expect(result.dateTime!.minute, 30);
    });

    test('Parse task with in X hours', () {
      final result = TaskParser.parseVoiceInput('Take medicine in 2 hours');
      expect(result.title, 'Take medicine');
      expect(result.dateTime, isNotNull);
      
      final inTwoHours = DateTime.now().add(const Duration(hours: 2));
      // Allow 1 minute difference for execution time
      expect(result.dateTime!.hour, inTwoHours.hour);
      expect((result.dateTime!.minute - inTwoHours.minute).abs() <= 1, true);
    });

    test('Clean up prepositions', () {
      final result = TaskParser.parseVoiceInput('Work on project tomorrow');
      expect(result.title, 'Work on project');
      
      final result2 = TaskParser.parseVoiceInput('Doctor at 10am');
      expect(result2.title, 'Doctor');
    });
  });
}
