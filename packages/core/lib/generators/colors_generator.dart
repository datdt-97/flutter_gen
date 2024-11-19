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

class ColorsGenerator {
  final File pubspecFile;
  final FlutterGenColors config;
  final DartFormatter formatter;

  String get className => config.outputs.className;

  List<String> get inputs => config.inputs;

  List<String> get themes => config.outputs.themes;

  ColorsGenerator({
    required this.pubspecFile,
    required this.config,
    required this.formatter,
  }) : assert(
          config.inputs.isNotEmpty,
          throw const InvalidSettingsException(
            'The value of "flutter_gen/colors:" is incorrect.',
          ),
        );

  String build() {
    final buffer = StringBuffer();
    final className = config.outputs.className;
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

    buffer.writeln('}');

    for (var i = 0; i < inputs.length; i++) {
      buffer.writeln(
        _generateThemeColors(className, inputs[i], themes[i]),
      );
    }

    buffer
      ..writeln(_generateColorsExtension(className, inputs.first))
      ..writeln(_generateTheme(className, inputs, themes))
      ..writeln(_generateThemeDataExtension(className))
      ..writeln(_generateThemeGetterExtension());

    return formatter.format(buffer.toString());
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
      ..writeln('final class ${theme.capitalize() + className} {')
      ..writeln('const ${theme.capitalize() + className}._();')
      ..writeln();

    buffer.writeln(
      _generateColors(input, mapper: _colorStatement),
    );

    buffer.writeln('}');

    return buffer.toString();
  }

  String _generateColorsExtension(
    String className,
    String input,
  ) {
    final buffer = StringBuffer();

    buffer
      ..writeln(
          'final class ${className}Extension extends ThemeExtension<${className}Extension> {')
      ..writeln();

    buffer.writeln(
      _generateColors(input, mapper: _colorVariable),
    );

    buffer.writeln('${className}Extension({');

    buffer.writeln(
      _generateColors(input, mapper: _requiredColorParam),
    );

    buffer
      ..writeln('});')
      ..writeln();

    buffer
      ..writeln('@override')
      ..writeln('ThemeExtension<${className}Extension> copyWith({');

    buffer.writeln(
      _generateColors(
        input,
        mapper: (color) => _requiredColorParam(color, isOptionalType: true),
      ),
    );

    buffer.writeln('}) {');

    buffer.writeln('return ${className}Extension(');

    buffer.writeln(
      _generateColors(
        input,
        mapper: (color) {
          final name = color.name.camelCase();
          return '$name: $name ?? this.$name,';
        },
      ),
    );

    buffer.writeln(');');

    buffer
      ..writeln('}')
      ..writeln();

    buffer.writeln('''
  @override
  ThemeExtension<${className}Extension> lerp(covariant ThemeExtension<${className}Extension>? other, double t,) {
    if (other is! ${className}Extension) {
      return this;
    }
    
    return ${className}Extension(
  ''');

    buffer.writeln(
      _generateColors(
        input,
        mapper: (color) {
          final name = color.name.camelCase();
          return '$name: Color.lerp($name, other.$name, t,)!,';
        },
      ),
    );

    buffer
      ..writeln(');')
      ..writeln('}');

    buffer.writeln('}');

    return buffer.toString();
  }

  String _generateTheme(
    String className,
    List<String> inputs,
    List<String> themes,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('class ${className}Theme {');

    for (var i = 0; i < inputs.length; i++) {
      buffer.writeln('''
    //
    // ${themes[i]} theme
    //

    ''');

      buffer.writeln('''
    static final ${themes[i]} = ThemeData.${themes[i]}().copyWith(
      extensions: [
        _${themes[i]}${className}Extension,
      ],
    );
    ''');

      buffer.writeln(
        'static final _${themes[i]}${className}Extension = ${className}Extension(',
      );

      buffer.writeln(
        _generateColors(inputs[i], mapper: (color) {
          final name = color.name.camelCase();
          return '$name: $className.${themes[i]}.$name,';
        }),
      );

      buffer
        ..writeln(');')
        ..writeln();
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  String _generateThemeDataExtension(String className) {
    return '''
  extension ${className}ThemeExtension on ThemeData {
    /// Usage example: Theme.of(context).appColors;
    ${className}Extension get appColors => extension<${className}Extension>() ?? ${className}Theme._light${className}Extension;
  }
  ''';
  }

  String _generateThemeGetterExtension() {
    return '''
      extension ThemeGetter on BuildContext {
        // Usage example: `context.theme`
        ThemeData get theme => Theme.of(this);
      }
    ''';
  }

  String _requiredColorParam(
    _Color color, {
    bool isOptionalType = false,
  }) {
    final buffer = StringBuffer();
    if (isOptionalType) {
      final type = switch (color) {
        _ when color.isMaterial => 'MaterialColor',
        _ when color.isMaterialAccent => 'MaterialAccentColor',
        _ when color.isNormal => 'Color',
        _ => '',
      };
      buffer.writeln('$type? ${color.name.camelCase()},');
    } else {
      buffer.writeln('required this.${color.name.camelCase()},');
    }
    return buffer.toString();
  }

  String _colorVariable(_Color color) {
    final buffer = StringBuffer();

    final type = switch (color) {
      _ when color.isMaterial => 'MaterialColor',
      _ when color.isMaterialAccent => 'MaterialAccentColor',
      _ when color.isNormal => 'Color',
      _ => '',
    };

    buffer.writeln('final $type ${color.name.camelCase()};');

    return buffer.toString();
  }

  String _colorStatement(_Color color) {
    final buffer = StringBuffer();
    if (color.isMaterial) {
      final swatch = swatchFromPrimaryHex(color.hex);
      final statement = '''/// MaterialColor: 
        ${swatch.entries.map((e) => '///   ${e.key}: ${hexFromColor(e.value)}').join('\n')}
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
      buffer.writeln(statement);
    }
    return buffer.toString();
  }

  String _generateColors(
    String input, {
    required String Function(_Color color) mapper,
  }) {
    final buffer = StringBuffer();

    final colorList = <_Color>[];
    final colorFile = ColorPath(input);
    final data = colorFile.file.readAsStringSync();
    if (colorFile.isXml) {
      colorList.addAll(
        XmlDocument.parse(data)
            .findAllElements('color')
            .map(_Color.fromXmlElement),
      );
    } else {
      throw 'Not supported file type ${colorFile.mime}.';
    }

    colorList
        .distinctBy((color) => color.name)
        .sortedBy((color) => color.name)
        .map(mapper)
        .forEach(buffer.write);

    return buffer.toString();
  }
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
