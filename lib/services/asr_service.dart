class AsrService {
  const AsrService();

  Future<String> transcribeAudio(List<int> bytes) {
    throw UnsupportedError(
      'Dashscope ASR is reserved for Phase 2. The MVP supports typed input only.',
    );
  }
}

