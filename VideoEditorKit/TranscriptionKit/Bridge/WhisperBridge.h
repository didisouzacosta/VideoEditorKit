#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TKWhisperBridgeTask) {
    TKWhisperBridgeTaskTranscribe,
    TKWhisperBridgeTaskTranslate,
};

@interface TKWhisperBridgeWord : NSObject

@property (nonatomic, readonly) NSTimeInterval startTime;
@property (nonatomic, readonly) NSTimeInterval endTime;
@property (nonatomic, copy, readonly) NSString *text;

- (instancetype)initWithStartTime:(NSTimeInterval)startTime
                          endTime:(NSTimeInterval)endTime
                             text:(NSString *)text;

@end

@interface TKWhisperBridgeSegment : NSObject

@property (nonatomic, readonly) NSTimeInterval startTime;
@property (nonatomic, readonly) NSTimeInterval endTime;
@property (nonatomic, copy, readonly) NSString *text;
@property (nonatomic, copy, readonly) NSArray<TKWhisperBridgeWord *> *words;

- (instancetype)initWithStartTime:(NSTimeInterval)startTime
                          endTime:(NSTimeInterval)endTime
                             text:(NSString *)text
                            words:(NSArray<TKWhisperBridgeWord *> *)words;

@end

@interface TKWhisperBridgeResult : NSObject

@property (nonatomic, copy, readonly) NSString *text;
@property (nonatomic, copy, readonly, nullable) NSString *language;
@property (nonatomic, copy, readonly) NSArray<TKWhisperBridgeSegment *> *segments;

- (instancetype)initWithText:(NSString *)text
                    language:(nullable NSString *)language
                    segments:(NSArray<TKWhisperBridgeSegment *> *)segments;

@end

@interface TKWhisperBridgeRequest : NSObject

@property (nonatomic, copy, readonly) NSURL *preparedAudioURL;
@property (nonatomic, copy, readonly) NSURL *modelURL;
@property (nonatomic, copy, readonly, nullable) NSString *language;
@property (nonatomic, readonly) TKWhisperBridgeTask task;

- (instancetype)initWithPreparedAudioURL:(NSURL *)preparedAudioURL
                                modelURL:(NSURL *)modelURL
                                language:(nullable NSString *)language
                                    task:(TKWhisperBridgeTask)task;

@end

FOUNDATION_EXPORT NSErrorDomain const TKWhisperBridgeErrorDomain;

typedef NS_ENUM(NSInteger, TKWhisperBridgeErrorCode) {
    TKWhisperBridgeErrorCodeRuntimeUnavailable = 1,
    TKWhisperBridgeErrorCodeInvalidRequest = 2,
    TKWhisperBridgeErrorCodeInferenceFailed = 3,
};

@interface TKWhisperBridgeExecutor : NSObject

- (nullable TKWhisperBridgeResult *)transcribe:(TKWhisperBridgeRequest *)request
                                         error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
