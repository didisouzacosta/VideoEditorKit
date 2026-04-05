#import "WhisperBridge.h"

#include "WhisperBridge.hpp"

NSErrorDomain const TKWhisperBridgeErrorDomain = @"TranscriptionKit.WhisperBridge";

namespace transcriptionkit {

static std::shared_ptr<WhisperRuntime> g_runtime;

void RegisterWhisperRuntime(std::shared_ptr<WhisperRuntime> runtime) {
    g_runtime = std::move(runtime);
}

std::shared_ptr<WhisperRuntime> SharedWhisperRuntime() {
    return g_runtime;
}

}  // namespace transcriptionkit

@implementation TKWhisperBridgeWord

- (instancetype)initWithStartTime:(NSTimeInterval)startTime
                          endTime:(NSTimeInterval)endTime
                             text:(NSString *)text {
    self = [super init];
    if (self) {
        _startTime = startTime;
        _endTime = endTime;
        _text = [text copy];
    }

    return self;
}

@end

@implementation TKWhisperBridgeSegment

- (instancetype)initWithStartTime:(NSTimeInterval)startTime
                          endTime:(NSTimeInterval)endTime
                             text:(NSString *)text
                            words:(NSArray<TKWhisperBridgeWord *> *)words {
    self = [super init];
    if (self) {
        _startTime = startTime;
        _endTime = endTime;
        _text = [text copy];
        _words = [words copy];
    }

    return self;
}

@end

@implementation TKWhisperBridgeResult

- (instancetype)initWithText:(NSString *)text
                    language:(nullable NSString *)language
                    segments:(NSArray<TKWhisperBridgeSegment *> *)segments {
    self = [super init];
    if (self) {
        _text = [text copy];
        _language = [language copy];
        _segments = [segments copy];
    }

    return self;
}

@end

@implementation TKWhisperBridgeRequest

- (instancetype)initWithPreparedAudioURL:(NSURL *)preparedAudioURL
                                modelURL:(NSURL *)modelURL
                                language:(nullable NSString *)language
                                    task:(TKWhisperBridgeTask)task {
    self = [super init];
    if (self) {
        _preparedAudioURL = [preparedAudioURL copy];
        _modelURL = [modelURL copy];
        _language = [language copy];
        _task = task;
    }

    return self;
}

@end

@implementation TKWhisperBridgeExecutor

- (nullable TKWhisperBridgeResult *)transcribe:(TKWhisperBridgeRequest *)request
                                         error:(NSError * _Nullable * _Nullable)error {
    if (request.preparedAudioURL == nil || request.modelURL == nil) {
        if (error != nil) {
            *error = [NSError errorWithDomain:TKWhisperBridgeErrorDomain
                                         code:TKWhisperBridgeErrorCodeInvalidRequest
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"The Whisper bridge received an invalid request.",
                                     }];
        }

        return nil;
    }

    auto runtime = transcriptionkit::SharedWhisperRuntime();
    if (runtime == nullptr) {
        if (error != nil) {
            *error = [NSError errorWithDomain:TKWhisperBridgeErrorDomain
                                         code:TKWhisperBridgeErrorCodeRuntimeUnavailable
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"Whisper runtime is not registered. Integrate whisper.cpp before calling the local bridge.",
                                     }];
        }

        return nil;
    }

    try {
        transcriptionkit::WhisperRequest native_request;
        native_request.prepared_audio_path = request.preparedAudioURL.path.UTF8String ?: "";
        native_request.model_path = request.modelURL.path.UTF8String ?: "";
        if (request.language != nil) {
            native_request.language = std::string(request.language.UTF8String ?: "");
        }
        native_request.task = request.task == TKWhisperBridgeTaskTranslate
            ? transcriptionkit::WhisperTask::kTranslate
            : transcriptionkit::WhisperTask::kTranscribe;

        transcriptionkit::WhisperResult native_result = runtime->Transcribe(native_request);
        NSMutableArray<TKWhisperBridgeSegment *> *segments = [NSMutableArray array];

        for (const transcriptionkit::WhisperSegment &native_segment : native_result.segments) {
            NSMutableArray<TKWhisperBridgeWord *> *words = [NSMutableArray array];

            for (const transcriptionkit::WhisperWord &native_word : native_segment.words) {
                NSString *word_text = [NSString stringWithUTF8String:native_word.text.c_str()] ?: @"";
                TKWhisperBridgeWord *word = [[TKWhisperBridgeWord alloc] initWithStartTime:native_word.start_time
                                                                                   endTime:native_word.end_time
                                                                                      text:word_text];
                [words addObject:word];
            }

            NSString *segment_text = [NSString stringWithUTF8String:native_segment.text.c_str()] ?: @"";
            TKWhisperBridgeSegment *segment = [[TKWhisperBridgeSegment alloc] initWithStartTime:native_segment.start_time
                                                                                         endTime:native_segment.end_time
                                                                                            text:segment_text
                                                                                           words:words];
            [segments addObject:segment];
        }

        NSString *text = [NSString stringWithUTF8String:native_result.text.c_str()] ?: @"";
        NSString *language = nil;
        if (native_result.language.has_value()) {
            language = [NSString stringWithUTF8String:native_result.language->c_str()];
        }

        return [[TKWhisperBridgeResult alloc] initWithText:text
                                                  language:language
                                                  segments:segments];
    } catch (const std::exception &exception) {
        if (error != nil) {
            *error = [NSError errorWithDomain:TKWhisperBridgeErrorDomain
                                         code:TKWhisperBridgeErrorCodeInferenceFailed
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: [NSString stringWithUTF8String:exception.what()] ?: @"Whisper inference failed.",
                                     }];
        }

        return nil;
    }
}

@end
