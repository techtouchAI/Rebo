/// Minimal ZIP archive writer used by the Word exporter.
///
/// Entries are stored uncompressed: a `.docx` is a ZIP container, and Word,
/// LibreOffice and every mobile office app read stored entries. Keeping the
/// writer local avoids adding an archive dependency to the application, and
/// makes the produced bytes fully deterministic.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Builds a ZIP archive from [entries] (name → content).
Uint8List buildStoredZip(Map<String, List<int>> entries) {
  const int dosTime = 0;
  const int dosDate = 0x0021; // 1980-01-01, the lower bound of the DOS format.
  final local = BytesBuilder(copy: false);
  final central = BytesBuilder(copy: false);
  var offset = 0;

  for (final MapEntry<String, List<int>> entry in entries.entries) {
    final List<int> name = utf8.encode(entry.key);
    final List<int> data = entry.value;
    final int crc = crc32(data);

    final ByteData header = ByteData(30);
    header
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(4, 20, Endian.little) // Version needed to extract.
      ..setUint16(6, 0x0800, Endian.little) // UTF-8 entry names.
      ..setUint16(8, 0, Endian.little) // Stored, no compression.
      ..setUint16(10, dosTime, Endian.little)
      ..setUint16(12, dosDate, Endian.little)
      ..setUint32(14, crc, Endian.little)
      ..setUint32(18, data.length, Endian.little)
      ..setUint32(22, data.length, Endian.little)
      ..setUint16(26, name.length, Endian.little)
      ..setUint16(28, 0, Endian.little);
    local
      ..add(header.buffer.asUint8List())
      ..add(name)
      ..add(data);

    final ByteData record = ByteData(46);
    record
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, 20, Endian.little) // Version made by.
      ..setUint16(6, 20, Endian.little) // Version needed.
      ..setUint16(8, 0x0800, Endian.little)
      ..setUint16(10, 0, Endian.little)
      ..setUint16(12, dosTime, Endian.little)
      ..setUint16(14, dosDate, Endian.little)
      ..setUint32(16, crc, Endian.little)
      ..setUint32(20, data.length, Endian.little)
      ..setUint32(24, data.length, Endian.little)
      ..setUint16(28, name.length, Endian.little)
      ..setUint16(30, 0, Endian.little)
      ..setUint16(32, 0, Endian.little)
      ..setUint16(34, 0, Endian.little)
      ..setUint16(36, 0, Endian.little)
      ..setUint32(38, 0, Endian.little)
      ..setUint32(42, offset, Endian.little);
    central
      ..add(record.buffer.asUint8List())
      ..add(name);

    offset += 30 + name.length + data.length;
  }

  final Uint8List localBytes = local.toBytes();
  final Uint8List centralBytes = central.toBytes();
  final ByteData end = ByteData(22);
  end
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(4, 0, Endian.little)
    ..setUint16(6, 0, Endian.little)
    ..setUint16(8, entries.length, Endian.little)
    ..setUint16(10, entries.length, Endian.little)
    ..setUint32(12, centralBytes.length, Endian.little)
    ..setUint32(16, localBytes.length, Endian.little)
    ..setUint16(20, 0, Endian.little);

  return (BytesBuilder(copy: false)
        ..add(localBytes)
        ..add(centralBytes)
        ..add(end.buffer.asUint8List()))
      .toBytes();
}

/// CRC-32 (IEEE 802.3) of [bytes], as required by the ZIP central directory.
int crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final int byte in bytes) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

final List<int> _crcTable = _buildCrcTable();

List<int> _buildCrcTable() {
  final table = List<int>.filled(256, 0);
  for (var i = 0; i < 256; i++) {
    var value = i;
    for (var bit = 0; bit < 8; bit++) {
      value = (value & 1) == 1 ? 0xEDB88320 ^ (value >> 1) : value >> 1;
    }
    table[i] = value & 0xFFFFFFFF;
  }
  return table;
}
