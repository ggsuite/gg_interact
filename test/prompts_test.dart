// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_interact/gg_interact.dart';
import 'package:test/test.dart';

// .............................................................................
/// Answers from a script instead of asking anybody.
class _ScriptedPrompts extends GgPrompts {
  const _ScriptedPrompts(this.answer);

  final int answer;

  @override
  Future<int> select({
    required String prompt,
    required List<String> options,
    int initialIndex = 0,
  }) async => answer;

  @override
  Future<String> input({
    required String prompt,
    String? defaultValue,
    String? initialText,
    bool asMessageEditor = false,
  }) async => 'scripted';
}

// .............................................................................
/// Records every question and answers from a list.
class _RecordingPrompts extends GgPrompts {
  _RecordingPrompts(this.answers);

  final List<String> answers;
  final selects = <({String prompt, List<String> options, int initialIndex})>[];
  final inputs =
      <({String prompt, String? defaultValue, String? initialText})>[];

  @override
  Future<int> select({
    required String prompt,
    required List<String> options,
    int initialIndex = 0,
  }) async {
    selects.add((prompt: prompt, options: options, initialIndex: initialIndex));
    return int.parse(answers.first);
  }

  @override
  Future<String> input({
    required String prompt,
    String? defaultValue,
    String? initialText,
    bool asMessageEditor = false,
  }) async {
    inputs.add((
      prompt: prompt,
      defaultValue: defaultValue,
      initialText: initialText,
    ));
    return answers.removeAt(0);
  }
}

void main() {
  tearDown(() => GgPrompts.current = null);

  group('GgPrompts', () {
    // #########################################################################
    group('current', () {
      test('starts out as the prompts of this platform', () {
        expect(GgPrompts.current, GgPrompts.defaultPrompts);
      });

      test('can be replaced and reset', () {
        const scripted = _ScriptedPrompts(1);

        GgPrompts.current = scripted;
        expect(GgPrompts.current, scripted);

        GgPrompts.current = null;
        expect(GgPrompts.current, GgPrompts.defaultPrompts);
      });

      test('is what the suite asks its questions through', () async {
        GgPrompts.current = const _ScriptedPrompts(2);

        expect(
          await GgPrompts.current.select(prompt: 'Pick', options: ['a', 'b']),
          2,
        );
        expect(await GgPrompts.current.input(prompt: 'Say'), 'scripted');
      });
    });

    // #########################################################################
    group('is asynchronous', () {
      test('so an embedder is free to read a line however it can', () {
        // The file system callbacks of GgHost have to be synchronous —
        // dart:io's ...Sync APIs cannot await. A prompt has no such
        // constraint, and forcing one would make an embedder block on its
        // input, which not every platform allows.
        const scripted = _ScriptedPrompts(0);
        expect(
          scripted.select(prompt: 'p', options: ['a']),
          isA<Future<int>>(),
        );
        expect(scripted.input(prompt: 'p'), isA<Future<String>>());
      });
    });

    // #########################################################################
    group('confirm()', () {
      test('is yes when the first option is picked', () async {
        expect(await const _ScriptedPrompts(0).confirm(prompt: 'Ok?'), true);
      });

      test('is no when the second option is picked', () async {
        expect(await const _ScriptedPrompts(1).confirm(prompt: 'Ok?'), false);
      });

      test('preselects the default answer', () async {
        final prompts = _RecordingPrompts(['1']);

        await prompts.confirm(prompt: 'Ok?', defaultValue: false);
        final asked = prompts.selects.single;
        expect(asked.prompt, 'Ok?');
        expect(asked.options, ['Yes', 'No']);
        expect(asked.initialIndex, 1);

        await prompts.confirm(prompt: 'Sure?');
        expect(prompts.selects.last.initialIndex, 0);
      });
    });

    // #########################################################################
    group('inputUntilValid()', () {
      test('asks again until the answer is valid', () async {
        final prompts = _RecordingPrompts(['', '  x y ', ' ok ']);
        final reasons = <String>[];

        final answer = await prompts.inputUntilValid(
          prompt: 'Name',
          defaultValue: 'd',
          initialText: 'i',
          validate: (answer) => answer.isEmpty
              ? 'empty'
              : answer.contains(' ')
              ? 'space'
              : null,
          onInvalid: reasons.add,
        );

        expect(answer, 'ok');
        expect(reasons, ['empty', 'space']);
        expect(prompts.inputs, hasLength(3));
        expect(prompts.inputs.first, (
          prompt: 'Name',
          defaultValue: 'd',
          initialText: 'i',
        ));
      });

      test('returns at once when the first answer is valid', () async {
        final prompts = _RecordingPrompts(['fine']);

        final answer = await prompts.inputUntilValid(
          prompt: 'Name',
          validate: (_) => null,
          onInvalid: (_) => fail('must not be called'),
        );

        expect(answer, 'fine');
        expect(prompts.inputs, hasLength(1));
      });
    });
  });

  // ###########################################################################
  group('GgPromptsUnsupportedError', () {
    test('names the question and what to do instead', () {
      final error = GgPromptsUnsupportedError('the version prompt');

      expect(error.message, contains('the version prompt'));
      expect(error.message, contains('command line'));
      expect(error.message, contains('GgPrompts.current'));
    });
  });
}
