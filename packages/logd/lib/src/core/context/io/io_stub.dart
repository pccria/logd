class HttpException implements Exception {
  const HttpException(this.message, {this.uri});
  final String message;
  final Uri? uri;
  @override
  String toString() => 'HttpException: $message';
}

class Stdout {
  void add(final List<int> data) {}
  bool get hasTerminal => false;
  int get terminalColumns => 80;
  bool get supportsAnsiEscapes => false;
  Future<void> flush() async {}
}

final stdout = Stdout();

const bool isStub = true;
