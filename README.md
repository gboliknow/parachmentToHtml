# parchment_to_html

Parchment To HTMl

## Note
HTML to Parchment for Flutter applications based on [Notus to Html](https://github.com/JacobWrenn/notustohtml). It uses a document model named Parchment based on Notus.
## Getting Started

This project is a generic Dart package used to convert between HTML and the Parchment document format.It is a replica of[ Notus to Html](https://github.com/JacobWrenn/notustohtml)  package for Zefyr but since [Zefyr](https://github.com/memspace/zefyr) is not longer manage and the alternative is [fleather](https://github.com/fleather-editor/fleather) which doesn't use Notus but Parchment , so to convert your parchement to html 


## Usage

### Encode HTML
 ```dart
  const converter = ParchmentHtmlCodec();
  String html = converter.encode(doc.toDelta());
  log(html); // The HTML representation of the ParchmentDocument
  ```

### Decode HTML
 ```dart
  Delta delta = converter.decode(html); // Fleather compatible Delta
  ParchmentDocument document = ParchmentDocument.fromDelta(delta);
  log(document.toString());
```
### Credits
This project is inspired by [Notus to Html](https://github.com/JacobWrenn/notustohtml). Credit is given to the original project for its contribution to this package.
