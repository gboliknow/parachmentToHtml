import 'dart:developer';

import 'package:fleather/fleather.dart';

import 'package:parchment_delta/parchment_delta.dart';

import 'package:parchment_to_html/parachment_to_html.dart';

void main() {
  const converter = ParchmentHtmlCodec();

  // Replace with the document you have take from the Zefyr editor
  final doc = ParchmentDocument.fromJson(
    [
      {
        "insert": "Hello World!",
      },
      {
        "insert": "\n",
        "attributes": {
          "heading": 1,
        },
      },
    ],
  );

  String html = converter.encode(doc.toDelta());
  log(html); // The HTML representation of the ParchmentDocument

  Delta delta = converter.decode(html); // Fleather compatible Delta
  ParchmentDocument document = ParchmentDocument.fromDelta(delta);
  log(document.toString());
}
