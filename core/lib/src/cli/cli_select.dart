import 'dart:io';

const _highlight = '\x1B[38;2;93;169;222m';
const _reset = '\x1B[0m';
const _hideCursor = '\x1B[?25l';
const _showCursor = '\x1B[?25h';

/// Display an interactive arrow-key selection menu.
///
/// Returns the index of the selected option, or -1 if cancelled.
int cliSelect({
  required List<String> options,
  String? prompt,
  int initial = 0,
}) {
  if (options.isEmpty) return -1;

  var selected = initial.clamp(0, options.length - 1);

  stdin.echoMode = false;
  stdin.lineMode = false;
  stdout.write(_hideCursor);

  void render() {
    // Move cursor back up to the first option line.
    for (var i = 0; i < options.length; i++) {
      stdout.write('\x1B[A'); // move up
    }
    stdout.write('\r');

    for (var i = 0; i < options.length; i++) {
      stdout.write('\x1B[2K'); // clear line
      if (i == selected) {
        stdout.writeln('$_highlight> ${options[i]}$_reset');
      } else {
        stdout.writeln('  ${options[i]}');
      }
    }
  }

  if (prompt != null) {
    stdout.writeln(prompt);
    stdout.writeln('');
  }

  // Print initial lines so render() can overwrite them.
  for (var i = 0; i < options.length; i++) {
    stdout.writeln('');
  }
  render();

  while (true) {
    final byte = stdin.readByteSync();

    if (byte == 27) {
      // Escape sequence.
      final next = stdin.readByteSync();
      if (next == 91) {
        final arrow = stdin.readByteSync();
        if (arrow == 65) {
          // Up arrow.
          selected = (selected - 1) % options.length;
          render();
        } else if (arrow == 66) {
          // Down arrow.
          selected = (selected + 1) % options.length;
          render();
        }
      } else if (next == -1) {
        // Bare escape - cancel.
        _cleanup();
        return -1;
      }
    } else if (byte == 10 || byte == 13) {
      // Enter.
      _cleanup();
      return selected;
    } else if (byte == 3) {
      // Ctrl+C.
      _cleanup();
      return -1;
    } else if (byte == 113 || byte == 81) {
      // q / Q.
      _cleanup();
      return -1;
    }
  }
}

void _cleanup() {
  stdout.write(_showCursor);
  stdin.echoMode = true;
  stdin.lineMode = true;
}
