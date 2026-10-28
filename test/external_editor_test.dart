// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_interact/gg_interact.dart';
import 'package:test/test.dart';

void main() {
  group('ExternalEditor', () {
    late List<String> logs;
    late List<List<String>> started;
    late List<bool> shells;

    setUp(() {
      logs = [];
      started = [];
      shells = [];
    });

    ExternalEditor editor({
      Map<String, String> environment = const {},
      String operatingSystem = 'windows',
      bool hasCode = false,
      String saved = 'saved',
      int exitCode = 0,
    }) => ExternalEditor(
      environment: environment,
      operatingSystem: operatingSystem,
      findExecutable: (name) => hasCode && name == 'code' ? 'code.cmd' : null,
      startEditor: (executable, arguments, {required runInShell}) async {
        started.add([executable, ...arguments]);
        shells.add(runInShell);
        File(arguments.last).writeAsStringSync(saved);
        return exitCode;
      },
      log: logs.add,
    );

    // #########################################################################
    group('command', () {
      test('prefers GG_EDITOR', () {
        expect(
          editor(
            environment: {'GG_EDITOR': 'my-editor -w', 'EDITOR': 'vim'},
            hasCode: true,
          ).command,
          ['my-editor', '-w'],
        );
      });

      test('takes VS Code before VISUAL and EDITOR', () {
        expect(editor(environment: {'EDITOR': 'vim'}, hasCode: true).command, [
          'code',
          '--wait',
        ]);
      });

      test('falls back to VISUAL, then EDITOR', () {
        expect(
          editor(environment: {'VISUAL': 'nano', 'EDITOR': 'vim'}).command,
          ['nano'],
        );
        expect(editor(environment: {'EDITOR': 'vim'}).command, ['vim']);
      });

      test('adds the wait flag an editor needs, also to a variable', () {
        expect(editor(environment: {'GG_EDITOR': 'cursor'}).command, [
          'cursor',
          '--wait',
        ]);
        expect(editor(environment: {'VISUAL': 'subl'}).command, ['subl', '-w']);
        expect(editor(environment: {'EDITOR': 'codium -n'}).command, [
          'codium',
          '-n',
          '--wait',
        ]);
      });

      group('on Linux', () {
        List<String>? linux(Map<String, String> environment) => editor(
          environment: {'EDITOR': 'vim', ...environment},
          operatingSystem: 'linux',
          hasCode: true,
        ).command;

        test('takes VS Code with a display', () {
          expect(linux({'DISPLAY': ':0'}), ['code', '--wait']);
          expect(linux({'WAYLAND_DISPLAY': 'wayland-0'}), ['code', '--wait']);
          expect(linux({'VSCODE_IPC_HOOK_CLI': '/tmp/x.sock'}), [
            'code',
            '--wait',
          ]);
        });

        test('skips VS Code without a display, e.g. via SSH', () {
          expect(linux({'DISPLAY': ''}), ['vim']);
        });

        test('keeps VS Code elsewhere without a display', () {
          expect(
            editor(
              environment: const {'EDITOR': 'vim'},
              operatingSystem: 'macos',
              hasCode: true,
            ).command,
            ['code', '--wait'],
          );
        });
      });

      test('reads the environment of the process by default', () {
        // Only looked up, nothing is started.
        expect(() => ExternalEditor().command, returnsNormally);
      });

      test('is null when no editor is known', () {
        expect(editor(environment: {'EDITOR': '  '}).command, isNull);
      });
    });

    // #########################################################################
    group('edit', () {
      test('returns what was saved and deletes the file', () async {
        final result = await editor(hasCode: true).edit(
          prompt: 'Edit the messages.',
          text: 'original',
          fileName: 'messages.jsonc',
        );

        expect(result, 'saved');
        expect(started.single.take(2), ['code', '--wait']);
        expect(shells.single, isTrue);
        expect(started.single.last, endsWith('messages.jsonc'));
        expect(File(started.single.last).existsSync(), isFalse);
        expect(logs.single, contains('Save and close messages.jsonc'));
      });

      test('hands the text to the editor', () async {
        String? shown;
        await ExternalEditor(
          environment: const {'EDITOR': 'vim'},
          findExecutable: (_) => null,
          startEditor: (executable, arguments, {required runInShell}) async {
            shown = File(arguments.last).readAsStringSync();
            return 0;
          },
          log: logs.add,
        ).edit(prompt: 'Edit.', text: 'original', fileName: 'a.txt');

        expect(shown, 'original');
      });

      test('reads a file that is no valid UTF-8', () async {
        final result = await ExternalEditor(
          environment: const {'EDITOR': 'vim'},
          findExecutable: (_) => null,
          startEditor: (executable, arguments, {required runInShell}) async {
            File(arguments.last).writeAsBytesSync([0xFF, 0x61]);
            return 0;
          },
          log: logs.add,
        ).edit(prompt: 'Edit.', text: 'original', fileName: 'a.txt');

        expect(result, '\uFFFDa');
      });

      test('returns null when no editor is known', () async {
        final result = await editor().edit(
          prompt: 'Edit.',
          text: 'original',
          fileName: 'a.txt',
        );
        expect(result, isNull);
        expect(started, isEmpty);
      });

      test('returns null when the editor cannot be started', () async {
        final result = await ExternalEditor(
          environment: const {'GG_EDITOR': 'vsocde'},
          findExecutable: (_) => null,
          startEditor: (executable, arguments, {required runInShell}) =>
              throw const ProcessException('vsocde', [], 'not found\n'),
          log: logs.add,
        ).edit(prompt: 'Edit.', text: 'original', fileName: 'a.txt');

        expect(result, isNull);
        expect(
          logs.last,
          'The editor "vsocde" could not be started (not found). '
          'Asking on the terminal instead.',
        );
      });

      test('throws when the editor fails', () async {
        await expectLater(
          editor(
            hasCode: true,
            exitCode: 2,
          ).edit(prompt: 'Edit.', text: 'original', fileName: 'a.txt'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('"code --wait" ended with exit code 2'),
            ),
          ),
        );
        expect(File(started.single.last).existsSync(), isFalse);
      });

      test('does not fail when the file cannot be deleted', () async {
        final temp = Directory.systemTemp;
        final created = <Directory>[];
        final result = await IOOverrides.runZoned(
          () =>
              editor(hasCode: true)
                  .edit(prompt: 'Edit.', text: 'original', fileName: 'a.txt'),
          getSystemTempDirectory: () => _UndeletableDir(temp, created),
        );

        expect(result, 'saved');
        expect(created.single.existsSync(), isTrue);
        created.single.deleteSync(recursive: true);
      });
    });

    // #########################################################################
    group('withWaitFlag', () {
      test('adds --wait to VS Code and its forks', () {
        for (final name in [
          'code',
          'Code.exe',
          'code-insiders',
          'cursor.cmd',
          'codium',
          r'C:\Program Files\Microsoft VS Code\bin\code',
          '/usr/bin/code',
        ]) {
          expect(ExternalEditor.withWaitFlag([name]), [name, '--wait']);
        }
      });

      test('adds -w to Sublime Text', () {
        expect(ExternalEditor.withWaitFlag(['subl']), ['subl', '-w']);
      });

      test('keeps a wait flag that is there', () {
        expect(ExternalEditor.withWaitFlag(['code', '-w']), ['code', '-w']);
        expect(ExternalEditor.withWaitFlag(['subl', '--wait', '-n']), [
          'subl',
          '--wait',
          '-n',
        ]);
      });

      test('leaves other editors alone', () {
        expect(ExternalEditor.withWaitFlag(['vim']), ['vim']);
        expect(ExternalEditor.withWaitFlag(['.code']), ['.code']);
        expect(ExternalEditor.withWaitFlag(['notepad++.exe', '-multiInst']), [
          'notepad++.exe',
          '-multiInst',
        ]);
      });
    });

    // #########################################################################
    group('launchOf', () {
      EditorLaunch launch(String name, String? resolved, {bool win = true}) =>
          ExternalEditor.launchOf(
            name,
            isWindows: win,
            findExecutable: (_) => resolved,
          );

      test('runs a batch file on Windows in a shell, by its name', () {
        expect(launch('code', r'C:\VS Code\bin\code.cmd'), (
          executable: 'code',
          runInShell: true,
        ));
        expect(launch('x', r'C:\x.BAT'), (executable: 'x', runInShell: true));
      });

      test('starts everything else directly, by its path', () {
        const notepad = r'C:\Program Files (x86)\Notepad++\notepad++.exe';
        expect(launch(notepad, notepad), (
          executable: notepad,
          runInShell: false,
        ));
        expect(launch('vim', r'C:\vim\vim.exe'), (
          executable: r'C:\vim\vim.exe',
          runInShell: false,
        ));
        expect(launch('code', '/opt/code.cmd', win: false), (
          executable: '/opt/code.cmd',
          runInShell: false,
        ));
      });

      test('starts an executable that is not found by its name', () {
        expect(launch('vim', null), (executable: 'vim', runInShell: false));
      });
    });

    // #########################################################################
    group('splitCommandLine', () {
      test('splits words and keeps quoted ones together', () {
        expect(ExternalEditor.splitCommandLine(''), isEmpty);
        expect(ExternalEditor.splitCommandLine(' code  --wait '), [
          'code',
          '--wait',
        ]);
        expect(
          ExternalEditor.splitCommandLine(
            '"C:\\Program Files\\Editor\\e.exe" -w \'a b\' ""',
          ),
          [r'C:\Program Files\Editor\e.exe', '-w', 'a b', ''],
        );
      });
    });

    // #########################################################################
    group('findOnPath', () {
      late Directory dir;
      final isWindows = Platform.isWindows;
      final separator = isWindows ? ';' : ':';

      setUp(() => dir = Directory.systemTemp.createTempSync('find_on_path_'));
      tearDown(() => dir.deleteSync(recursive: true));

      test('finds the file in one of the directories', () {
        File('${dir.path}${Platform.pathSeparator}code.exe')
            .writeAsStringSync('');
        expect(
          ExternalEditor.findOnPath(
            'code.exe',
            path: '${dir.path}x$separator$separator${dir.path}',
            isWindows: isWindows,
          ),
          endsWith('code.exe'),
        );
      });

      test('finds a file without extension except on Windows', () {
        File('${dir.path}${Platform.pathSeparator}code').writeAsStringSync('');
        expect(
          ExternalEditor.findOnPath(
            'code',
            path: dir.path,
            isWindows: isWindows,
            pathExt: '.EXE;.CMD',
          ),
          isWindows ? isNull : endsWith('code'),
        );
      });

      test('tries the extensions of PATHEXT on Windows', () {
        // VS Code ships both: the script for Git Bash and the batch file.
        File('${dir.path}${Platform.pathSeparator}code').writeAsStringSync('');
        File('${dir.path}${Platform.pathSeparator}code.cmd')
            .writeAsStringSync('');
        expect(
          ExternalEditor.findOnPath(
            'code',
            path: dir.path,
            isWindows: true,
            pathExt: '.EXE;.CMD',
          ),
          endsWith('code.cmd'),
        );
      }, skip: !isWindows);

      test('looks a name with a folder up only there', () {
        final file = '${dir.path}${Platform.pathSeparator}my editor.exe';
        File(file).writeAsStringSync('');
        expect(
          ExternalEditor.findOnPath(
            file,
            path: '/nowhere',
            isWindows: isWindows,
          ),
          file,
        );
        expect(
          ExternalEditor.findOnPath(
            '${dir.path}/missing',
            path: dir.path,
            isWindows: false,
          ),
          isNull,
        );
      });

      test('tries no extensions elsewhere', () {
        expect(
          ExternalEditor.findOnPath('code', path: '/nowhere', isWindows: false),
          isNull,
        );
      });

      test('returns null when nothing is found', () {
        expect(
          ExternalEditor.findOnPath(
            'code',
            path: dir.path,
            isWindows: isWindows,
          ),
          isNull,
        );
      });
    });
  });
}

/// The system temp folder, but the folders created in it cannot be deleted.
class _UndeletableDir implements Directory {
  _UndeletableDir(this._dir, this._created);

  final Directory _dir;
  final List<Directory> _created;

  @override
  String get path => _dir.path;

  @override
  Future<Directory> createTemp([String? prefix]) async {
    final dir = await _dir.createTemp(prefix);
    _created.add(dir);
    return _UndeletableDir(dir, _created);
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      throw FileSystemException('In use', path);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
