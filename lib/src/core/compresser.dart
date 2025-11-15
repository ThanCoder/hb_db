import 'dart:io';

class ZLibWriterSink implements Sink<List<int>> {
  final RandomAccessFile file;
  final void Function(int written)? onWrite;

  ZLibWriterSink(this.file, this.onWrite);

  @override
  void add(List<int> data) async {
    await file.writeFrom(data);
    onWrite?.call(data.length);
  }

  @override
  void close() {}
}

// Helper wrapper for IOSink so that startChunkedConversion works
class IOSinkWrapper implements Sink<List<int>> {
  final IOSink _sink;
  final void Function(int count) _onWrite;

  IOSinkWrapper(this._sink, this._onWrite);

  @override
  void add(List<int> data) {
    _sink.add(data);
    _onWrite(data.length);
  }

  @override
  void close() => _sink.close();
}
