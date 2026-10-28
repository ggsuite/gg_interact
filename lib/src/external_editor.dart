// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:io';

/// Starts [executable] with [arguments] attached to the terminal and returns
/// its exit code once it ends. [runInShell] starts it through the shell.
typedef StartEditor = Future<int> Function(
  String executable,
  List<String> arguments, {
  required bool runInShell,
});

/// Returns the path of [name] on the `PATH`, or null when it is not there.
typedef FindExecutable = String? Function(String name);

/// How an editor is started: the [executable] handed to the operating system
/// and whether it needs a shell.
typedef EditorLaunch = ({String executable, bool runInShell});

/// Opens a text in the editor of the user and waits until it is closed.
///
/// The editor is the first of
///
/// 1. `GG_EDITOR` — a command line just for gg, e.g. `code --wait`,
/// 2. VS Code (`code --wait`) when `code` is on the `PATH` — on Linux only
///    with a display, not in an SSH session,
/// 3. `VISUAL` and `EDITOR`, the editors git and most shells use.
///
/// VS Code comes before `VISUAL` and `EDITOR` on purpose: those are often set
/// to a terminal editor once and forgotten, while gg wants the messages of a
/// ticket side by side in the editor the code is written in.
///
/// Editors that return at once unless told to wait — VS Code and its forks,
/// Sublime Text — get their wait flag, also when it is missing in a variable.
class ExternalEditor {
  /// Constructor. [operatingSystem] is a value of [Platform.operatingSystem].
  ExternalEditor({
    Map<String, String>? environment,
    String? operatingSystem,
    FindExecutable? findExecutable,
    StartEditor? startEditor,
    void Function(String message)? log,
  }) : _environment = environment ?? Platform.environment,
       _operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _findExecutable = findExecutable ?? _defaultFindExecutable,
       _startEditor = startEditor ?? _defaultStartEditor,
       _log = log ?? print;

  final Map<String, String> _environment;
  final String _operatingSystem;
  final FindExecutable _findExecutable;
  final StartEditor _startEditor;
  final void Function(String message) _log;

  bool get _isWindows => _operatingSystem == 'windows';

  /// The command line the editor is started with — the file is appended —
  /// or null when no editor is known.
  List<String>? get command {
    final ggEditor = splitCommandLine(_environment['GG_EDITOR'] ?? '');
    if (ggEditor.isNotEmpty) {
      return withWaitFlag(ggEditor);
    }

    if (_canShowVsCode && _findExecutable('code') != null) {
      return const ['code', '--wait'];
    }

    for (final variable in const ['VISUAL', 'EDITOR']) {
      final editor = splitCommandLine(_environment[variable] ?? '');
      if (editor.isNotEmpty) {
        return withWaitFlag(editor);
      }
    }
    return null;
  }

  /// Whether a VS Code window can reach the user. Not on a Linux box without
  /// a display — an SSH session — unless VS Code's own terminal runs gg.
  bool get _canShowVsCode =>
      _operatingSystem != 'linux' ||
      const [
        'DISPLAY',
        'WAYLAND_DISPLAY',
        'VSCODE_IPC_HOOK_CLI',
      ].any((variable) => (_environment[variable] ?? '').isNotEmpty);

  /// Writes [text] into a temporary file named [fileName], opens it in the
  /// editor and returns what the user saved once the editor is closed.
  ///
  /// Returns null when no editor is known or it cannot be started — the
  /// caller then asks its questions on the terminal. [prompt] tells the user
  /// what to do while gg waits. Throws when the editor ends with an error,
  /// like git does: the user cancelled. The temporary file is deleted in any
  /// case.
  Future<String?> edit({
    required String prompt,
    required String text,
    required String fileName,
  }) async {
    final command = this.command;
    if (command == null) {
      return null;
    }

    final dir = await Directory.systemTemp.createTemp('gg_edit_');
    try {
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(text);

      final launch = launchOf(
        command.first,
        isWindows: _isWindows,
        findExecutable: _findExecutable,
      );
      _log('$prompt Save and close $fileName to continue.');
      final int exitCode;
      try {
        exitCode = await _startEditor(launch.executable, [
          ...command.skip(1),
          file.path,
        ], runInShell: launch.runInShell);
      } on ProcessException catch (e) {
        _log(
          'The editor "${command.join(' ')}" could not be started '
          '(${e.message.trim()}). Asking on the terminal instead.',
        );
        return null;
      }
      if (exitCode != 0) {
        throw Exception(
          'The editor "${command.join(' ')}" ended with exit code $exitCode.',
        );
      }
      // An editor may save in another encoding than UTF-8; a broken
      // character is better than a crash.
      return utf8.decode(await file.readAsBytes(), allowMalformed: true);
    } finally {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // A file still held open by the editor; the system cleans up later.
      }
    }
  }

  // ...........................................................................
  /// [command] with the flag that makes the editor wait until the file is
  /// closed, when it is one of the editors that return at once without it.
  static List<String> withWaitFlag(List<String> command) {
    final name = _baseName(command.first);
    final hasFlag = command.skip(1).any((a) => a == '--wait' || a == '-w');
    if (hasFlag) {
      return command;
    }
    if (const ['code', 'code-insiders', 'cursor', 'codium'].contains(name)) {
      return [...command, '--wait'];
    }
    if (name == 'subl') {
      return [...command, '-w'];
    }
    return command;
  }

  /// The file name of [executable] without folder and extension, lower case.
  static String _baseName(String executable) {
    final name = executable.split(RegExp(r'[\\/]')).last.toLowerCase();
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// How [executable] is started. A batch file — `code` is `code.cmd` on
  /// Windows — runs only in a shell, so it gets one and its name as it was
  /// written. Everything else starts directly, by its path when it is found:
  /// the shell of Windows would break a quoted path like
  /// `C:\Program Files (x86)\Notepad++\notepad++.exe`.
  static EditorLaunch launchOf(
    String executable, {
    required bool isWindows,
    required FindExecutable findExecutable,
  }) {
    final resolved = findExecutable(executable);
    final lower = resolved?.toLowerCase() ?? '';
    if (isWindows && (lower.endsWith('.cmd') || lower.endsWith('.bat'))) {
      return (executable: executable, runInShell: true);
    }
    return (executable: resolved ?? executable, runInShell: false);
  }

  // ...........................................................................
  /// Splits the command line of an editor variable into its words. Double
  /// and single quotes group words, so an editor below `C:\Program Files`
  /// can be named.
  static List<String> splitCommandLine(String commandLine) {
    final words = <String>[];
    final word = StringBuffer();
    var hasWord = false;
    String? quote;

    for (final char in commandLine.split('')) {
      if (quote != null) {
        if (char == quote) {
          quote = null;
        } else {
          word.write(char);
        }
      } else if (char == '"' || char == "'") {
        quote = char;
        hasWord = true;
      } else if (char.trim().isEmpty) {
        if (hasWord) {
          words.add(word.toString());
          word.clear();
          hasWord = false;
        }
      } else {
        word.write(char);
        hasWord = true;
      }
    }
    if (hasWord) {
      words.add(word.toString());
    }
    return words;
  }

  /// Looks [name] up in the directories of [path]. A [name] with a folder in
  /// it is only looked up there.
  ///
  /// On Windows, like Windows itself, with the extensions of [pathExt] —
  /// `code` is `code.cmd` — and as it is only when it has an extension:
  /// next to `code.cmd` lies `code`, a shell script for Git Bash that Windows
  /// cannot start, and Git puts more of them on the `PATH`, e.g. `notepad`.
  static String? findOnPath(
    String name, {
    required String path,
    required bool isWindows,
    String pathExt = '',
  }) {
    final hasFolder = name.contains('/') || (isWindows && name.contains(r'\'));
    final slash = isWindows ? r'\' : '/';
    final baseName = name.split(isWindows ? RegExp(r'[\\/]') : '/').last;
    final extensions = isWindows
        ? [
            if (baseName.contains('.')) '',
            ...pathExt.split(';').where((e) => e.isNotEmpty),
          ]
        : [''];
    final candidates = hasFolder
        ? [name]
        : [
            for (final dir in path.split(isWindows ? ';' : ':'))
              if (dir.isNotEmpty) '$dir$slash$name',
          ];

    for (final candidate in candidates) {
      for (final extension in extensions) {
        final file = '$candidate${extension.toLowerCase()}';
        if (File(file).existsSync()) {
          return file;
        }
      }
    }
    return null;
  }

  // coverage:ignore-start
  static String? _defaultFindExecutable(String name) => findOnPath(
    name,
    path: Platform.environment['PATH'] ?? '',
    isWindows: Platform.isWindows,
    pathExt: Platform.environment['PATHEXT'] ?? '.COM;.EXE;.BAT;.CMD',
  );

  static Future<int> _defaultStartEditor(
    String executable,
    List<String> arguments, {
    required bool runInShell,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.inheritStdio,
      runInShell: runInShell,
    );
    return process.exitCode;
  }

  // coverage:ignore-end
}
