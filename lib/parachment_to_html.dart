library parchmenttohtml;
import 'dart:convert';

import 'package:fleather/fleather.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:parchment_delta/parchment_delta.dart';

class ParchmentHtmlCodec extends Codec<Delta, String> {
  const ParchmentHtmlCodec();

  @override
  Converter<String, Delta> get decoder => _ParchmentHtmlDecoder();

  @override
  Converter<Delta, String> get encoder => _ParchmentHtmlEncoder();
}

class _ParchmentHtmlEncoder extends Converter<Delta, String> {
  static const kBold = 'strong';
  static const kItalic = 'em';
  static final kSimpleBlocks = <ParchmentAttribute, String>{
    ParchmentAttribute.bq: 'blockquote',
    ParchmentAttribute.ul: 'ul',
    ParchmentAttribute.ol: 'ol',
  };

  @override
  String convert(Delta input) {
    final iterator = DeltaIterator(input);
    final buffer = StringBuffer();
    final lineBuffer = StringBuffer();
    ParchmentAttribute<String>? currentBlockStyle;
    var currentInlineStyle = ParchmentStyle();
    var currentBlockLines = [];

    void handleBlock(ParchmentAttribute<String>? blockStyle) {
      if (currentBlockLines.isEmpty) {
        return; // Empty block
      }

      if (blockStyle == null) {
        buffer.write(currentBlockLines.join('\n\n'));
        buffer.writeln();
      } else if (blockStyle == ParchmentAttribute.code) {
        _writeAttribute(buffer, blockStyle);
        buffer.write(currentBlockLines.join('\n'));
        _writeAttribute(buffer, blockStyle, close: true);
        buffer.writeln();
      } else if (blockStyle == ParchmentAttribute.bq) {
        _writeAttribute(buffer, blockStyle);
        buffer.write(currentBlockLines.join('\n'));
        _writeAttribute(buffer, blockStyle, close: true);
        buffer.writeln();
      } else if (blockStyle == ParchmentAttribute.ol ||
          blockStyle == ParchmentAttribute.ul) {
        _writeAttribute(buffer, blockStyle);
        buffer.write("<li>");
        buffer.write(currentBlockLines.join('</li><li>'));
        buffer.write("</li>");
        _writeAttribute(buffer, blockStyle, close: true);
        buffer.writeln();
      } else {
        for (var line in currentBlockLines) {
          _writeBlockTag(buffer, blockStyle);
          buffer.write(line);
          buffer.writeln();
        }
      }
      buffer.writeln();
    }

    void handleSpan(String text, Map<String, dynamic>? attributes,
        {bool hr = false, String? source}) {
      final style = ParchmentStyle.fromJson(attributes);
      currentInlineStyle = _writeInline(
          lineBuffer, text, style, currentInlineStyle,
          hr: hr, source: source);
    }

    void handleLine(Map<String, dynamic>? attributes) {
      final style = ParchmentStyle.fromJson(attributes);
      final lineBlock = style.get(ParchmentAttribute.block);
      if (lineBlock == currentBlockStyle) {
        currentBlockLines.add(_writeLine(lineBuffer.toString(), style));
      } else {
        handleBlock(currentBlockStyle);
        currentBlockLines.clear();
        currentBlockLines.add(_writeLine(lineBuffer.toString(), style));

        currentBlockStyle = lineBlock;
      }
      lineBuffer.clear();
    }

    while (iterator.hasNext) {
      Operation op = iterator.next();
      bool hr = false;
      String? source;
      if (op.data is BlockEmbed) {
        final embed = op.data as BlockEmbed;
        if (embed.type == "hr") {
          op = Operation.insert("");
          hr = true;
        } else if (embed.type == "image") {
          op = Operation.insert("");
          source = embed.data["source"];
        }
      } else if (op.data is Map) {
        final map = op.data as Map;
        if (map["_type"] == "hr") {
          op = Operation.insert("");
          hr = true;
        } else if (map["_type"] == "image") {
          op = Operation.insert("");
          source = map["source"];
        }
      }
      final opText = op.data is String ? op.data as String : '';
      final lf = opText.indexOf('\n');
      if (lf == -1) {
        handleSpan(opText, op.attributes, hr: hr, source: source);
      } else {
        var span = StringBuffer();
        for (var i = 0; i < opText.length; i++) {
          if (opText.codeUnitAt(i) == 0x0A) {
            if (span.isNotEmpty) {
              // Write the span if it's not empty.
              handleSpan(span.toString(), op.attributes);
            }
            // Close any open inline styles.
            handleSpan('', null);
            handleLine(op.attributes);
            span.clear();
          } else {
            span.writeCharCode(opText.codeUnitAt(i));
          }
        }
        // Remaining span
        if (span.isNotEmpty) {
          handleSpan(span.toString(), op.attributes);
        }
      }
    }
    handleBlock(currentBlockStyle); // Close the last block
    return buffer.toString().replaceAll("\n", "<br>");
  }

  String _writeLine(String text, ParchmentStyle style) {
    var buffer = StringBuffer();
    if (style.contains(ParchmentAttribute.heading)) {
      _writeAttribute(buffer, style.get<int>(ParchmentAttribute.heading));
    }

    // Write the text itself
    buffer.write(text);
    // Close the heading
    if (style.contains(ParchmentAttribute.heading)) {
      _writeAttribute(buffer, style.get<int>(ParchmentAttribute.heading),
          close: true);
    }
    return buffer.toString();
  }

  String _trimRight(StringBuffer buffer) {
    var text = buffer.toString();
    if (!text.endsWith(' ')) return '';
    final result = text.trimRight();
    buffer.clear();
    buffer.write(result);
    return ' ' * (text.length - result.length);
  }

  ParchmentStyle _writeInline(StringBuffer buffer, String text,
      ParchmentStyle style, ParchmentStyle currentStyle,
      {bool? hr, String? source}) {
    ParchmentAttribute? wasA;
    // First close any current styles if needed
    for (var value in currentStyle.values.toList().reversed) {
      if (value.scope == ParchmentAttributeScope.line) continue;
      if (value.key == "a") {
        wasA = value;
        continue;
      }
      //if (style.containsSame(value)) continue;
      final padding = _trimRight(buffer);
      _writeAttribute(buffer, value, close: true);
      if (padding.isNotEmpty) buffer.write(padding);
    }
    if (wasA != null) {
      _writeAttribute(buffer, wasA, close: true);
    }
    // Now open any new styles.
    for (var value in style.values) {
      if (value.scope == ParchmentAttributeScope.line) continue;
      //if (currentStyle.containsSame(value)) continue;
      final originalText = text;
      text = text.trimLeft();
      final padding = ' ' * (originalText.length - text.length);
      if (padding.isNotEmpty) buffer.write(padding);
      _writeAttribute(buffer, value);
    }
    if (source != null) {
      buffer.write("<img src=\"$source\">");
    }
    if (hr!) {
      buffer.write("<hr>");
    }
    // Write the text itself
    buffer.write(text);
    return style;
  }

  void _writeAttribute(StringBuffer buffer, ParchmentAttribute? attribute,
      {bool close = false}) {
    if (attribute == ParchmentAttribute.bold) {
      _writeBoldTag(buffer, close: close);
    } else if (attribute == ParchmentAttribute.italic) {
      _writeItalicTag(buffer, close: close);
    } else if (attribute == ParchmentAttribute.underline) {
      _writeTag(buffer, close: close, tag: "u");
    } else if (attribute == ParchmentAttribute.strikethrough) {
      _writeTag(buffer, close: close, tag: "del");
    } else if (attribute!.key == ParchmentAttribute.link.key) {
      _writeLinkTag(buffer, attribute as ParchmentAttribute<String?>?,
          close: close);
    } else if (attribute.key == ParchmentAttribute.heading.key) {
      _writeHeadingTag(buffer, attribute as ParchmentAttribute<int?>,
          close: close);
    } else if (attribute.key == ParchmentAttribute.block.key) {
      _writeBlockTag(buffer, attribute as ParchmentAttribute<String?>?,
          close: close);
    } else {
      throw ArgumentError('Cannot handle $attribute');
    }
  }

  void _writeBoldTag(StringBuffer buffer, {bool close = false}) {
    buffer.write(!close ? "<$kBold>" : "</$kBold>");
  }

  void _writeTag(StringBuffer buffer, {bool close = false, String? tag}) {
    buffer.write(!close ? "<$tag>" : "</$tag>");
  }

  void _writeItalicTag(StringBuffer buffer, {bool close = false}) {
    buffer.write(!close ? "<$kItalic>" : "</$kItalic>");
  }

  void _writeLinkTag(StringBuffer buffer, ParchmentAttribute<String?>? link,
      {bool close = false}) {
    if (close) {
      buffer.write('</a>');
    } else {
      buffer.write('<a href="${link!.value}">');
    }
  }

  void _writeHeadingTag(StringBuffer buffer, ParchmentAttribute<int?> heading,
      {bool close = false}) {
    var level = heading.value;
    buffer.write(!close ? "<h$level>" : "</h$level>");
  }

  void _writeBlockTag(StringBuffer buffer, ParchmentAttribute<String?>? block,
      {bool close = false}) {
    if (block == ParchmentAttribute.code) {
      if (!close) {
        buffer.write('\n<code>');
      } else {
        buffer.write('</code>\n');
      }
    } else {
      if (!close) {
        buffer.write('<${kSimpleBlocks[block!]}>');
      } else {
        buffer.write('</${kSimpleBlocks[block!]}>');
      }
    }
  }
}

class _ParchmentHtmlDecoder extends Converter<String, Delta> {
  @override
  Delta convert(String input) {
    Delta delta = Delta();
    Document html = parse(input);

    html.body!.nodes.asMap().forEach((index, node) {
      dynamic next;
      if (index + 1 < html.body!.nodes.length) {
        next = html.body!.nodes[index + 1];
      }
      delta = _parseNode(node, delta, next);
    });
    final text = delta.last.data is String ? delta.last.data as String : '';
    if (text.endsWith("\n")) {
      return delta;
    }
    return delta..insert("\n");
  }

  Delta _parseNode(node, Delta delta, next, {isNewLine, inBlock}) {
    if (node.runtimeType == Element) {
      Element element = node;
      if (element.localName == "ul") {
        for (var child in element.children) {
          delta = _parseElement(
              child, delta, _supportedElements[child.localName!],
              listType: "ul",
              next: next,
              isNewLine: isNewLine,
              inBlock: inBlock);
        }
      }
      if (element.localName == "ol") {
        for (var child in element.children) {
          delta = _parseElement(
              child, delta, _supportedElements[child.localName!],
              listType: "ol",
              next: next,
              isNewLine: isNewLine,
              inBlock: inBlock);
        }
      }
      if (_supportedElements[element.localName!] == null) {
        return delta;
      }
      delta = _parseElement(
          element, delta, _supportedElements[element.localName!],
          next: next, isNewLine: isNewLine, inBlock: inBlock);
      return delta;
    } else {
      Text text = node;
      if (next != null &&
          next.runtimeType == Element &&
          next.localName == "br") {
        delta.insert("${text.text}\n");
      } else {
        delta.insert(text.text);
      }
      return delta;
    }
  }

  Delta _parseElement(Element element, Delta delta, String? type,
      {Map<String, dynamic>? attributes,
      String? listType,
      next,
      isNewLine,
      inBlock}) {
    if (type == "block") {
      Map<String, dynamic> blockAttributes = {};
      if (inBlock != null) blockAttributes = inBlock;
      if (element.localName == "h1") {
        blockAttributes["heading"] = 1;
      }
      if (element.localName == "h2") {
        blockAttributes["heading"] = 2;
      }
      if (element.localName == "h3") {
        blockAttributes["heading"] = 3;
      }
      if (element.localName == "blockquote") {
        blockAttributes["block"] = "quote";
      }
      if (element.localName == "code") {
        blockAttributes["block"] = "code";
      }
      if (element.localName == "li") {
        blockAttributes["block"] = listType;
      }
      element.nodes.asMap().forEach((index, node) {
        dynamic next;
        if (index + 1 < element.nodes.length) next = element.nodes[index + 1];
        delta = _parseNode(node, delta, next,
            isNewLine: element.localName == "li" ||
                element.localName == "p" ||
                element.localName == "div",
            inBlock: blockAttributes);
      });
      if (inBlock == null) {
        delta.insert("\n", blockAttributes);
      }
      return delta;
    } else if (type == "embed") {
      if (element.localName == "img") {
        delta = delta
          ..insert(BlockEmbed.image(element.attributes["src"]!).toJson());
      }
      if (element.localName == "hr") {
        delta = delta..insert(BlockEmbed.horizontalRule.toJson());
      }
      return delta;
    } else {
      attributes ??= {};
      if (element.localName == "em") {
        attributes["i"] = true;
      }
      if (element.localName == "strong") {
        attributes["b"] = true;
      }
      if (element.localName == "u") {
        attributes["u"] = true;
      }
      if (element.localName == "del") {
        attributes["s"] = true;
      }
      if (element.localName == "a") {
        attributes["a"] = element.attributes["href"];
      }
      if (element.children.isEmpty) {
        if (attributes["a"] != null) {
          delta.insert(element.text, attributes);
          if ((isNewLine == null || (isNewLine != null && !isNewLine)) &&
              inBlock == null) delta.insert("\n");
        } else {
          if (next != null &&
              next.runtimeType == Element &&
              next.localName == "br") {
            delta.insert("${element.text}\n", attributes);
          } else {
            delta.insert(element.text, attributes);
          }
        }
      } else {
        for (var node in element.nodes) {
          if (node.runtimeType == Element) {
            var elementType = _supportedElements[(node as Element).localName!];
            if (elementType == null) {
              continue;
            }
            delta = _parseElement(node, delta, elementType,
                attributes: attributes, next: next);
          } else if (node.runtimeType == Text) {
            delta = _parseNode(node, delta, next);
          }
        }
      }
      return delta;
    }
  }

  final Map<String, String> _supportedElements = {
    "li": "block",
    "blockquote": "block",
    "code": "block",
    "h1": "block",
    "h2": "block",
    "h3": "block",
    "div": "block",
    "em": "inline",
    "strong": "inline",
    "u": "inline",
    "del": "inline",
    "a": "inline",
    "p": "block",
    "img": "embed",
    "hr": "embed",
  };
}
