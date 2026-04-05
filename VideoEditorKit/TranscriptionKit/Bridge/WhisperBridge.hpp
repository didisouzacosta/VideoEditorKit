#pragma once

#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace transcriptionkit {

enum class WhisperTask {
    kTranscribe,
    kTranslate,
};

struct WhisperWord {
    double start_time;
    double end_time;
    std::string text;
};

struct WhisperSegment {
    double start_time;
    double end_time;
    std::string text;
    std::vector<WhisperWord> words;
};

struct WhisperRequest {
    std::string prepared_audio_path;
    std::string model_path;
    std::optional<std::string> language;
    WhisperTask task;
};

struct WhisperResult {
    std::string text;
    std::optional<std::string> language;
    std::vector<WhisperSegment> segments;
};

class WhisperRuntime {
public:
    virtual ~WhisperRuntime() = default;
    virtual WhisperResult Transcribe(const WhisperRequest &request) = 0;
};

void RegisterWhisperRuntime(std::shared_ptr<WhisperRuntime> runtime);
std::shared_ptr<WhisperRuntime> SharedWhisperRuntime();

}  // namespace transcriptionkit
