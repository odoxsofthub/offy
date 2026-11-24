import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/presentation/widgets/common/chat/app_chat_input_bar_widget.dart';
import 'package:office_app/presentation/widgets/common/chat/app_chat_mention_text_editing_controller.dart';
import 'package:office_app/presentation/widgets/common/chat/app_chat_send_icon_widget.dart';

void main() {
  group('AppChatMentionTextEditingController Unit Tests', () {
    test('insertMention adds a single MentionEntity and updates text', () {
      final controller = AppChatMentionTextEditingController(text: '@');
      controller.insertMention(
        name: 'dbg',
        id: 42,
        atIndex: 0,
        replaceLength: 1,
      );

      expect(controller.text, '@dbg ');
      expect(controller.selectedMentionEntities.length, 1);
      expect(controller.selectedMentionEntities.first.name, 'dbg');
      expect(controller.selectedMentionEntities.first.id, 42);
      expect(controller.selectedMentionEntities.first.start, 0);
      expect(controller.selectedMentionEntities.first.end, 4);
      expect(controller.selectedMentionNames, ['dbg']);
    });

    test('typing unselected text does NOT create a MentionEntity', () {
      final controller = AppChatMentionTextEditingController(text: '');
      controller.value = const TextEditingValue(text: '@dbg');

      expect(controller.selectedMentionEntities, isEmpty);
      expect(controller.selectedMentionNames, isEmpty);
      expect(controller.getMentionRanges(), isEmpty);
    });

    test('typing after a mention shifts subsequent mentions correctly', () {
      final controller = AppChatMentionTextEditingController(text: '');
      controller.insertMention(
        name: 'dbg',
        id: 1,
        atIndex: 0,
        replaceLength: 0,
      );
      // text is '@dbg '

      // Append text at the end
      controller.value = const TextEditingValue(text: '@dbg hello @');
      controller.insertMention(
        name: 'dbg2',
        id: 2,
        atIndex: 11,
        replaceLength: 1,
      );

      expect(controller.text, '@dbg hello @dbg2 ');
      expect(controller.selectedMentionEntities.length, 2);
      expect(controller.selectedMentionEntities[0].name, 'dbg');
      expect(controller.selectedMentionEntities[0].start, 0);
      expect(controller.selectedMentionEntities[0].end, 4);

      expect(controller.selectedMentionEntities[1].name, 'dbg2');
      expect(controller.selectedMentionEntities[1].start, 11);
      expect(controller.selectedMentionEntities[1].end, 16);
    });

    test('editing a selected mention invalidates it to plain text', () {
      final controller = AppChatMentionTextEditingController(text: '');
      controller.insertMention(
        name: 'dbg',
        id: 1,
        atIndex: 0,
        replaceLength: 0,
      );
      expect(controller.selectedMentionEntities.length, 1);

      // User deletes 'g' from '@dbg ' -> '@db '
      controller.value = const TextEditingValue(text: '@db ');
      expect(controller.selectedMentionEntities, isEmpty);
      expect(controller.selectedMentionNames, isEmpty);
    });

    test('emoji characters before/after mention shift offsets correctly', () {
      final controller = AppChatMentionTextEditingController(text: '');
      controller.insertMention(
        name: 'demo',
        id: 5,
        atIndex: 0,
        replaceLength: 0,
      );
      // text is '@demo '

      // User types/pastes emoji '👋 ' at start
      controller.value = const TextEditingValue(text: '👋 @demo ');
      expect(controller.selectedMentionEntities.length, 1);
      final entity = controller.selectedMentionEntities.first;
      expect(entity.name, 'demo');
      expect(entity.start, 3);
      expect(entity.end, 8);
      expect(controller.text.substring(entity.start, entity.end), '@demo');

      // User types emoji ' 🚀' at end
      controller.value = const TextEditingValue(text: '👋 @demo 🚀');
      expect(controller.selectedMentionEntities.length, 1);
      expect(controller.selectedMentionEntities.first.start, 3);
      expect(controller.selectedMentionEntities.first.end, 8);
    });

    test('names with parentheses, hyphens, and spaces', () {
      const complexName =
          'Employment Development Department (EDD) - State of California';
      final controller = AppChatMentionTextEditingController(text: '');
      controller.insertMention(
        name: complexName,
        id: 99,
        atIndex: 0,
        replaceLength: 0,
      );

      expect(controller.selectedMentionEntities.length, 1);
      final entity = controller.selectedMentionEntities.first;
      expect(entity.name, complexName);
      expect(controller.text, '@$complexName ');
      expect(controller.selectedMentionNames, [complexName]);
    });

    test(
      'inserting a mention in between existing mentions maintains order and offsets',
      () {
        final controller = AppChatMentionTextEditingController(text: '');
        controller.insertMention(
          name: 'Alice',
          id: 1,
          atIndex: 0,
          replaceLength: 0,
        );
        // text: '@Alice '
        controller.value = const TextEditingValue(text: '@Alice and @');
        controller.insertMention(
          name: 'Charlie',
          id: 3,
          atIndex: 11,
          replaceLength: 1,
        );
        // text: '@Alice and @Charlie '

        // Insert @Bob in the middle
        controller.value = const TextEditingValue(
          text: '@Alice and @ and @Charlie ',
        );
        controller.insertMention(
          name: 'Bob',
          id: 2,
          atIndex: 11,
          replaceLength: 2,
        );

        expect(controller.text, '@Alice and @Bob and @Charlie ');
        expect(controller.selectedMentionEntities.length, 3);
        expect(controller.selectedMentionNames, ['Alice', 'Bob', 'Charlie']);
        expect(controller.selectedMentionEntities[0].name, 'Alice');
        expect(controller.selectedMentionEntities[1].name, 'Bob');
        expect(controller.selectedMentionEntities[2].name, 'Charlie');
      },
    );

    test('select all and clear resets entities without leaks', () {
      final controller = AppChatMentionTextEditingController(text: '');
      controller.insertMention(
        name: 'demo',
        id: 1,
        atIndex: 0,
        replaceLength: 0,
      );
      expect(controller.selectedMentionEntities.length, 1);

      controller.clear();
      expect(controller.text, isEmpty);
      expect(controller.selectedMentionEntities, isEmpty);
    });
  });

  group('AppChatInputBarWidget End-to-End Widget Tests', () {
    testWidgets(
      'Single tap on suggestion selects mention immediately and closes popup',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = TextEditingController();
        String? sentText;
        List<String>? sentMentionNames;
        String? sentBodyParts;

        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, child) => MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: AppChatInputBarWidget(
                    controller: controller,
                    onSend: () {},
                    mentionableMembers: const [
                      (id: 101, name: 'dbg', avatarUrl: ''),
                      (id: 102, name: 'dbg2', avatarUrl: ''),
                    ],
                    onSendWithFiles: (text, files, mentions, bodyParts) {
                      sentText = text;
                      sentMentionNames = mentions;
                      sentBodyParts = bodyParts;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initially no mention popup
        expect(find.text('dbg'), findsNothing);

        // 2. Type '@' -> suggestion list appears with dbg and dbg2
        await tester.enterText(find.byType(TextField), '@');
        await tester.pumpAndSettle();

        expect(find.text('dbg'), findsOneWidget);
        expect(find.text('dbg2'), findsOneWidget);

        // 3. Single tap on 'dbg' -> converts to '@dbg ' and popup closes
        await tester.tap(find.text('dbg'));
        await tester.pumpAndSettle();

        expect(controller.text, '@dbg ');
        // Suggestion popup is closed!
        expect(find.text('dbg2'), findsNothing);

        // 4. Tap Send button
        await tester.tap(find.byType(AppChatSendIconWidget));
        await tester.pumpAndSettle();

        expect(sentText, '@dbg');
        expect(sentMentionNames, ['dbg']);
        expect(sentBodyParts, contains('"type":"mention"'));
        expect(sentBodyParts, contains('"partner_id":101'));
      },
    );

    testWidgets(
      'Typing without tapping leaves text plain and sends no mentions',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = TextEditingController();
        String? sentText;
        List<String>? sentMentionNames;
        String? sentBodyParts;

        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, child) => MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: AppChatInputBarWidget(
                    controller: controller,
                    onSend: () {},
                    mentionableMembers: const [
                      (id: 101, name: 'dbg', avatarUrl: ''),
                    ],
                    onSendWithFiles: (text, files, mentions, bodyParts) {
                      sentText = text;
                      sentMentionNames = mentions;
                      sentBodyParts = bodyParts;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Type plain text '@dbg2 ' without tapping suggestion
        await tester.enterText(find.byType(TextField), '@dbg2 ');
        await tester.pumpAndSettle();

        // Tap Send
        await tester.tap(find.byType(AppChatSendIconWidget));
        await tester.pumpAndSettle();

        expect(sentText, '@dbg2');
        expect(sentMentionNames, isEmpty);
        expect(sentBodyParts, isNot(contains('"type":"mention"')));
      },
    );

    testWidgets('Multiple mentions are selected and serialized correctly', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = TextEditingController();
      String? sentText;
      List<String>? sentMentionNames;
      String? sentBodyParts;

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, child) => MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: AppChatInputBarWidget(
                  controller: controller,
                  onSend: () {},
                  mentionableMembers: const [
                    (id: 101, name: 'dbg', avatarUrl: ''),
                    (id: 102, name: 'dbg2', avatarUrl: ''),
                  ],
                  onSendWithFiles: (text, files, mentions, bodyParts) {
                    sentText = text;
                    sentMentionNames = mentions;
                    sentBodyParts = bodyParts;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Type first '@' and tap dbg
      await tester.enterText(find.byType(TextField), '@');
      await tester.pumpAndSettle();
      await tester.tap(find.text('dbg'));
      await tester.pumpAndSettle();

      expect(controller.text, '@dbg ');

      // Type second '@' after space and tap dbg2
      await tester.enterText(find.byType(TextField), '@dbg and @');
      await tester.pumpAndSettle();
      expect(find.text('dbg2'), findsOneWidget);

      await tester.tap(find.text('dbg2'));
      await tester.pumpAndSettle();

      expect(controller.text, '@dbg and @dbg2 ');

      // Tap Send
      await tester.tap(find.byType(AppChatSendIconWidget));
      await tester.pumpAndSettle();

      expect(sentText, '@dbg and @dbg2');
      expect(sentMentionNames, ['dbg', 'dbg2']);
      expect(sentBodyParts, contains('"partner_id":101'));
      expect(sentBodyParts, contains('"partner_id":102'));
    });

    testWidgets(
      'Deleting space before mention reverts it to normal string without deleting text',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = TextEditingController();
        String? sentText;
        List<String>? sentMentionNames;
        String? sentBodyParts;

        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, child) => MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: AppChatInputBarWidget(
                    controller: controller,
                    onSend: () {},
                    mentionableMembers: const [
                      (id: 101, name: 'dbg', avatarUrl: ''),
                    ],
                    onSendWithFiles: (text, files, mentions, bodyParts) {
                      sentText = text;
                      sentMentionNames = mentions;
                      sentBodyParts = bodyParts;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Type "i am @" and select dbg
        await tester.enterText(find.byType(TextField), 'i am @');
        await tester.pumpAndSettle();
        await tester.tap(find.text('dbg'));
        await tester.pumpAndSettle();

        expect(controller.text, 'i am @dbg ');
        expect(find.text('dbg'), findsNothing); // popup closed

        // 2. Delete space before @ -> "i am@dbg "
        controller.value = const TextEditingValue(
          text: 'i am@dbg ',
          selection: TextSelection.collapsed(offset: 4),
        );
        await tester.pumpAndSettle();

        // Text is preserved as normal string, not deleted
        expect(controller.text, 'i am@dbg ');
        expect(find.text('dbg'), findsNothing);

        // 3. Send message
        await tester.tap(find.byType(AppChatSendIconWidget));
        await tester.pumpAndSettle();

        // am@dbg is sent as normal plain string, not a mention
        expect(sentText, 'i am@dbg');
        expect(sentMentionNames, isEmpty);
        expect(sentBodyParts, isNot(contains('"type":"mention"')));
      },
    );
  });
}
