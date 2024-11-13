import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter_gen_core/generators/generator_helper.dart';
import 'package:flutter_gen_core/settings/color_path.dart';
import 'package:flutter_gen_core/settings/pubspec.dart';
import 'package:flutter_gen_core/utils/color.dart';
import 'package:flutter_gen_core/utils/error.dart';
import 'package:flutter_gen_core/utils/string.dart';
import 'package:xml/xml.dart';

String generateColors(
  File pubspecFile,
  DartFormatter formatter,
  FlutterGenColors colorsConfig,
) {
  if (colorsConfig.inputs.isEmpty) {
    throw const InvalidSettingsException(
      'The value of "flutter_gen/colors:" is incorrect.',
    );
  }

  final inputs = colorsConfig.inputs;
  final themes = colorsConfig.outputs.themes;

  final buffer = StringBuffer();
  final className = colorsConfig.outputs.className;
  buffer.writeln('// dart format width=${formatter.pageWidth}');
  buffer.writeln(header);
  buffer.writeln(ignore);
  buffer.writeln("import 'package:flutter/painting.dart';");
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln();
  buffer.writeln('abstract final class $className {');
  buffer.writeln();

  for (var i = 0; i < inputs.length; i++) {
    buffer.writeln(
      _generateThemeColorsContainer(className, inputs[i], themes[i]),
    );
  }

  buffer.writeln(_generateWithThemeFunction(className, inputs, themes));

  buffer.writeln('}');

  buffer.writeln(
    _generateSealedColorClassesWithTheme(className, inputs.first),
  );

  for (var i = 0; i < inputs.length; i++) {
    buffer.writeln(
      _generateThemeColors(className, inputs[i], themes[i]),
    );
  }

  return formatter.format(buffer.toString());
  // return buffer.toString();
}

String _colorStatement(_Color color) {
  final buffer = StringBuffer();
  if (color.isMaterial) {
    final swatch = swatchFromPrimaryHex(color.hex);
    final statement = '''/// MaterialColor: 
        ${swatch.entries.map((e) => '///   ${e.key}: ${hexFromColor(e.value)}').join('\n')}
        @override
        MaterialColor get ${color.name.camelCase()} => const MaterialColor(
    ${swatch[500]},
    <int, Color>{
      ${swatch.entries.map((e) => '${e.key}: Color(${e.value}),').join('\n')}
    },
  );''';
    buffer.writeln(statement);
  }
  if (color.isMaterialAccent) {
    final accentSwatch = accentSwatchFromPrimaryHex(color.hex);
    final statement = '''/// MaterialAccentColor: 
        ${accentSwatch.entries.map((e) => '///   ${e.key}: ${hexFromColor(e.value)}').join('\n')}
        @override
        MaterialAccentColor get ${color.name.camelCase()}Accent => const MaterialAccentColor(
   ${accentSwatch[200]},
   <int, Color>{
     ${accentSwatch.entries.map((e) => '${e.key}: Color(${e.value}),').join('\n')}
    },
  );''';
    buffer.writeln(statement);
  }
  if (color.isNormal) {
    final comment = '/// Color: ${color.hex}';
    final statement =
        '''Color get ${color.name.camelCase()} => const Color(${colorFromHex(color.hex)});''';

    buffer.writeln(comment);
    buffer.writeln('@override');
    buffer.writeln(statement);
  }
  return buffer.toString();
}

String _abstractColorStatement(_Color color) {
  final buffer = StringBuffer();
  if (color.isMaterial) {
    final swatch = swatchFromPrimaryHex(color.hex);
    final statement = '''/// MaterialColor: 
        ${swatch.entries.map((e) => '///   ${e.key}: ${color.name.camelCase()}[${e.value}]').join('\n')}
        MaterialColor get ${color.name.camelCase()};''';
    buffer.writeln(statement);
  }
  if (color.isMaterialAccent) {
    final accentSwatch = accentSwatchFromPrimaryHex(color.hex);
    final statement = '''/// MaterialAccentColor: 
        ${accentSwatch.entries.map((e) => '///   ${e.key}: ${color.name.camelCase()}[${e.value}]').join('\n')}
        MaterialAccentColor get ${color.name.camelCase()}Accent;''';
    buffer.writeln(statement);
  }
  if (color.isNormal) {
    final comment = '/// Color: ${color.name.camelCase()}';
    final statement = '''Color get ${color.name.camelCase()};''';

    buffer.writeln(comment);
    buffer.writeln(statement);
  }
  return buffer.toString();
}

String _generateWithThemeFunction(
  String className,
  List<String> inputs,
  List<String> themes,
) {
  final buffer = StringBuffer();

  buffer.writeln(
    'static ${className}Theme withTheme(${className}Theme theme) => switch(theme) {',
  );
  for (final theme in themes) {
    buffer.writeln(
      '${theme.capitalize() + className}() => ${theme.capitalize() + className}._(),',
    );
  }
  buffer.writeln('};');

  return buffer.toString();
}

String _generateSealedColorClassesWithTheme(
  String className,
  String input,
) {
  final buffer = StringBuffer();

  buffer
    ..writeln('sealed class ${className}Theme {')
    ..writeln('const ${className}Theme._();');

  final colorList = <_Color>[];
  final colorFile = ColorPath(input);
  final data = colorFile.file.readAsStringSync();
  if (colorFile.isXml) {
    colorList
        .addAll(XmlDocument.parse(data).findAllElements('color').map((element) {
      return _Color.fromXmlElement(element);
    }));
  } else {
    throw 'Not supported file type ${colorFile.mime}.';
  }

  colorList
      .distinctBy((color) => color.name)
      .sortedBy((color) => color.name)
      .map(_abstractColorStatement)
      .forEach(buffer.write);

  buffer.writeln('}');

  return buffer.toString();
}

String _generateThemeColorsContainer(
  String className,
  String input,
  String theme,
) {
  final buffer = StringBuffer();

  buffer
    ..writeln('/// Colors for theme: $theme')
    ..writeln('/// with input: $input')
    ..writeln(
      'static const ${theme.capitalize() + className} $theme = ${theme.capitalize() + className}._();',
    );

  return buffer.toString();
}

String _generateThemeColors(
  String className,
  String input,
  String theme,
) {
  final buffer = StringBuffer();

  buffer
    ..writeln(
        'final class ${theme.capitalize() + className} extends ${className}Theme {')
    ..writeln('const ${theme.capitalize() + className}._(): super._();')
    ..writeln();

  final colorList = <_Color>[];
  final colorFile = ColorPath(input);
  final data = colorFile.file.readAsStringSync();
  if (colorFile.isXml) {
    colorList
        .addAll(XmlDocument.parse(data).findAllElements('color').map((element) {
      return _Color.fromXmlElement(element);
    }));
  } else {
    throw 'Not supported file type ${colorFile.mime}.';
  }

  colorList
      .distinctBy((color) => color.name)
      .sortedBy((color) => color.name)
      .map(_colorStatement)
      .forEach(buffer.write);

  buffer.writeln('}');

  return buffer.toString();
}

class _Color {
  const _Color(
    this.name,
    this.hex,
    this._types,
  );

  _Color.fromXmlElement(XmlElement element)
      : this(
          element.getAttribute('name')!,
          // ignore: deprecated_member_use
          element.text,
          element.getAttribute('type')?.split(' ') ?? List.empty(),
        );

  final String name;

  final String hex;

  final List<String> _types;

  bool get isNormal => _types.isEmpty;

  bool get isMaterial => _types.contains('material');

  bool get isMaterialAccent => _types.contains('material-accent');
}
