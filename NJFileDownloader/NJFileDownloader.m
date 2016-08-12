//
//  NJFileDownloader.m
//  NJFileDownloader
//
//  Created by Luke on 16/5/18.
//  Copyright © 2016年 Luke. All rights reserved.
//

#import "NJFileDownloader.h"


// learn from AFNetworking
#ifndef NSFoundationVersionNumber_iOS_8_0
#define NSFoundationVersionNumber_With_Fixed_5871104061079552_bug 1140.11
#else
#define NSFoundationVersionNumber_With_Fixed_5871104061079552_bug NSFoundationVersionNumber_iOS_8_0
#endif

static dispatch_queue_t url_session_manager_creation_queue() {
    static dispatch_queue_t af_url_session_manager_creation_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        af_url_session_manager_creation_queue = dispatch_queue_create("com.alamofire.networking.session.manager.creation", DISPATCH_QUEUE_SERIAL);
    });
    
    return af_url_session_manager_creation_queue;
}

static void url_session_manager_create_task_safely(dispatch_block_t block) {
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_With_Fixed_5871104061079552_bug) {
        // Fix of bug
        // Open Radar:http://openradar.appspot.com/radar?id=5871104061079552 (status: Fixed in iOS8)
        // Issue about:https://github.com/AFNetworking/AFNetworking/issues/2093
        dispatch_sync(url_session_manager_creation_queue(), block);
    } else {
        block();
    }
}

typedef void (^NJFileResumeCancelHandler)(NSData *resumeData);

@interface NJFileDownloaderTask : NSObject <NJFileDownloaderTask>

@property (nonatomic, copy) NSString *resultPath;
@property (nonatomic, copy) NSURL *downloadFileURL;
@property (nonatomic, strong) NSError *error;

@property (nonatomic, copy) void (^completionHandler)(NSError *);
@property (nonatomic, copy) void (^progressHandler)(id<NJFileDownloaderTask>);
@property (nonatomic, copy) void (^pauseHandler)();
@property (nonatomic, copy) void (^cancelHandler)();
@property (nonatomic, copy) void (^cancelByProducingResumeDataHandler)(NJFileResumeCancelHandler completionHandler);
@property (nonatomic, copy) void (^resumeHandler)();

@property (nonatomic, assign) int64_t totalBytesWritten;
@property (nonatomic, assign) int64_t totalBytesExpectedToWrite;

@property (nonatomic, strong) NSDictionary *userInfo;

@end

@implementation NJFileDownloaderTask

- (void)pause
{
    if (self.pauseHandler) {
        self.pauseHandler();
    }
}

- (void)resume
{
    if (self.resumeHandler) {
        self.resumeHandler();
    }
}

- (void)cancel
{
    if (self.cancelHandler) {
        self.cancelHandler();
    }
}

- (void)cancelByProducingResumeData:(void (^)(NSData *))completionHandler
{
    if (self.cancelByProducingResumeDataHandler) {
        self.cancelByProducingResumeDataHandler(completionHandler);
    }
}

- (double)fractionCompleted
{
    if (self.totalBytesExpectedToWrite == 0) {
        return 0;
    } else {
        return (double)self.totalBytesWritten/self.totalBytesExpectedToWrite;
    }
}

@end

#pragma mark -

@interface NJFileDownloader () <NSURLSessionDownloadDelegate>

@end

@implementation NJFileDownloader
{
    NSURLSession *_downloadSession;
    NSURLSessionConfiguration *_sessionConfiguration;
    NSOperationQueue *_delegateQueue;
    NSMapTable *_mapTable;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _delegateQueue = [[NSOperationQueue alloc] init];
        _delegateQueue.maxConcurrentOperationCount = 1; //serial
        _mapTable = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory capacity:1];
        _sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _downloadSession = [NSURLSession sessionWithConfiguration:_sessionConfiguration
                                                         delegate:self
                                                    delegateQueue:_delegateQueue];
    }
    return self;
}

- (void)setAllowsCellularAccess:(BOOL)allowsCellularAccess
{
    _sessionConfiguration.allowsCellularAccess = allowsCellularAccess;
}

- (BOOL)allowsCellularAccess
{
    return _sessionConfiguration.allowsCellularAccess;
}

- (id<NJFileDownloaderTask>)downloadRequest:(NSURLRequest *)request toPath:(NSString *)resultPath completion:(void (^)(NSError *))completionHandler
{
    return [self downloadRequest:request toPath:resultPath progress:NULL completion:completionHandler];
}

- (id<NJFileDownloaderTask>)downloadRequest:(NSURLRequest *)request toPath:(NSString *)resultPath progress:(void (^)(id<NJFileDownloaderTask>))downloadProgressHandler completion:(void (^)(NSError *))completionHandler
{
    __block NSURLSessionDownloadTask *downloadTask = nil;
    url_session_manager_create_task_safely(^{
        downloadTask = [_downloadSession downloadTaskWithRequest:request];
    });
   
    return [self runSessionTask:downloadTask toPath:resultPath progress:downloadProgressHandler completion:completionHandler];
}


- (id<NJFileDownloaderTask>)downloadWithResumeData:(NSData *)resumeData
                                            toPath:(NSString *)resultPath
                                          progress:(void (^)(id<NJFileDownloaderTask> downloadTask))downloadProgressHandler
                                        completion:(void(^)(NSError *error))completionHandler
{
    __block NSURLSessionDownloadTask *downloadTask = nil;
    url_session_manager_create_task_safely(^{
        downloadTask = [_downloadSession downloadTaskWithResumeData:resumeData];
    });
    
    return [self runSessionTask:downloadTask toPath:resultPath progress:downloadProgressHandler completion:completionHandler];
}

- (id<NJFileDownloaderTask>)runSessionTask:(NSURLSessionTask *)downloadTask toPath:(NSString *)resultPath progress:(void (^)(id<NJFileDownloaderTask>))downloadProgressHandler completion:(void (^)(NSError *))completionHandler
{
    NJFileDownloaderTask *info = [[NJFileDownloaderTask alloc] init];
    info.resultPath = resultPath;
    info.completionHandler = completionHandler;
    info.progressHandler = downloadProgressHandler;
    
    __weak typeof(downloadTask) weakTask = downloadTask;
    info.resumeHandler = ^{
        __typeof__(weakTask) strongTask = weakTask;
        [strongTask resume];
    };
    
    info.cancelHandler = ^{
        __typeof__(weakTask) strongTask = weakTask;
        [strongTask cancel];
    };
    
    info.pauseHandler = ^{
        __typeof__(weakTask) strongTask = weakTask;
        [strongTask suspend];
    };
    
    __weak typeof(self) weakSelf = self;
    [_delegateQueue addOperationWithBlock:^{
        __strong typeof(weakSelf) sself = weakSelf;
        if (sself) {
            [sself->_mapTable setObject:info forKey:downloadTask];
        }
    }];
    
    [downloadTask resume];
    return info;
}

#pragma mark - callback

- (void)didDownloadFileForInfo:(NJFileDownloaderTask *)info fileURL:(NSURL *)location
{
    info.downloadFileURL = location;
    
    // get file size
    uint64_t fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:[location path] error:nil] fileSize];
    if (fileSize > 0) {
        NSURL *resultUrl = [NSURL fileURLWithPath:info.resultPath];
        [[NSFileManager defaultManager] removeItemAtURL:resultUrl error:NULL];
        NSError *error = nil;
        [[NSFileManager defaultManager] moveItemAtURL:info.downloadFileURL toURL:resultUrl error:&error];
        info.error = error;
    } else {
        info.error = [NSError errorWithDomain:@"NJFileDownloaderError" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Download a zero size file"}];
    }
    
    NSURL *resultUrl = [NSURL fileURLWithPath:info.resultPath];
    [[NSFileManager defaultManager] removeItemAtURL:resultUrl error:NULL];
    NSError *error = nil;
    [[NSFileManager defaultManager] moveItemAtURL:info.downloadFileURL toURL:resultUrl error:&error];
    info.error = error;
}

- (void)completeDownloadForRequestObject:(id)obj withError:(NSError *)error
{
    NJFileDownloaderTask *info = [_mapTable objectForKey:obj];
    if (info) {
        
        if (!error) {
            error = info.error;
        }
        
        if (info.completionHandler) {
            NSOperationQueue *callbackQueue = self.callbackQueue ?: [NSOperationQueue mainQueue];
            [callbackQueue addOperationWithBlock:^{
                info.completionHandler(error);
            }];
        }
        [_mapTable removeObjectForKey:obj];
    }
}

#pragma mark - NSURLSession delegate

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location
{    
    NJFileDownloaderTask *info = [_mapTable objectForKey:downloadTask];
    [self didDownloadFileForInfo:info fileURL:location];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
    totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    NJFileDownloaderTask *info = [_mapTable objectForKey:downloadTask];
    info.totalBytesWritten = totalBytesWritten;
    info.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
    
    if (info.progressHandler) {
        NSOperationQueue *callbackQueue = self.callbackQueue ?: [NSOperationQueue mainQueue];
        [callbackQueue addOperationWithBlock:^{
            info.progressHandler(info);
        }];
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error
{
    [self completeDownloadForRequestObject:task withError:error];
}

+ (NSData *)getResumeData:(NSError *)error
{
    return [[error userInfo] objectForKey:NSURLSessionDownloadTaskResumeData];
}

@end
