import 'dart:io';

import 'package:path/path.dart' as p;

import 'native_desktop.dart';

/// Saves a PNG to [outputPath]: prefers the **foreground work window** (not this app) on macOS,
/// otherwise falls back to full primary display. Requires screen-recording permission on macOS.
///
/// [playShutterSound]: on macOS, passes `-x` to `screencapture` when false (no system shutter).
Future<bool> captureScreenToFile(
  String outputPath, {
  bool playShutterSound = true,
}) async {
  final dir = Directory(p.dirname(outputPath));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  if (Platform.isMacOS || Platform.isWindows) {
    final workArea = await NativeDesktop.captureWorkAreaToFile(
      outputPath,
      playShutterSound: playShutterSound,
    );
    if (workArea) return true;
  }
  if (Platform.isMacOS) {
    final args = playShutterSound
        ? <String>['-C', outputPath]
        : <String>['-x', '-C', outputPath];
    final r = await Process.run('screencapture', args);
    return r.exitCode == 0;
  }
  if (Platform.isWindows) {
    final escaped = outputPath.replaceAll("'", "''");
    final script = '''
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
\$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
\$bmp = New-Object System.Drawing.Bitmap \$b.Width, \$b.Height
\$g = [System.Drawing.Graphics]::FromImage(\$bmp)
\$g.CopyFromScreen(\$b.Location, [System.Drawing.Point]::Empty, \$b.Size)
\$bmp.Save('$escaped', [System.Drawing.Imaging.ImageFormat]::Png)
\$g.Dispose()
\$bmp.Dispose()
''';
    final r = await Process.run(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', script],
    );
    return r.exitCode == 0 && File(outputPath).existsSync();
  }
  return false;
}
