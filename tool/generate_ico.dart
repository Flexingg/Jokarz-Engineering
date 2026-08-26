import 'dart:io';
import 'dart:typed_data';

void main() {
  final pngFile = File('assets/icons/app_icon.png');
  if (!pngFile.existsSync()) {
    print('PNG file not found: assets/icons/app_icon.png');
    return;
  }

  final pngBytes = pngFile.readAsBytesSync();
  final pngSize = pngBytes.length;

  // Build ICO header + entry for 256x256 PNG
  final byteData = ByteData(6 + 16);
  // ICONDIR
  byteData.setUint16(0, 0, Endian.little); // idReserved
  byteData.setUint16(2, 1, Endian.little); // idType (1 = ICO)
  byteData.setUint16(4, 1, Endian.little); // idCount (1 image)

  // ICONDIRENTRY
  byteData.setUint8(6, 0); // bWidth: 0 = 256px
  byteData.setUint8(7, 0); // bHeight: 0 = 256px
  byteData.setUint8(8, 0); // bColorCount
  byteData.setUint8(9, 0); // bReserved
  byteData.setUint16(10, 1, Endian.little); // wPlanes
  byteData.setUint16(12, 32, Endian.little); // wBitCount
  byteData.setUint32(14, pngSize, Endian.little); // dwBytesInRes
  byteData.setUint32(18, 6 + 16, Endian.little); // dwImageOffset

  final icoBytes = BytesBuilder();
  icoBytes.add(byteData.buffer.asUint8List());
  icoBytes.add(pngBytes);

  final icoFile = File('windows/runner/resources/app_icon.ico');
  icoFile.writeAsBytesSync(icoBytes.toBytes());
  print('Generated windows/runner/resources/app_icon.ico (${icoBytes.length} bytes)');
}
