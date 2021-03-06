//
//  NJFileDownloader.h
//  NJFileDownloader
//
//  Created by Luke on 16/5/18.
//  Copyright © 2016年 Luke. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NJFileDownloaderTask <NSObject>

@property (nonatomic, strong) NSDictionary *userInfo;

- (double)fractionCompleted;

- (void)pause;
- (void)resume;
- (void)cancel;
- (void)cancelByProducingResumeData:(void (^)(NSData *resumeData))completionHandler;

@end

@interface NJFileDownloader : NSObject

@property (nonatomic, strong) NSOperationQueue *callbackQueue;  //default is main queue
@property (nonatomic, assign) BOOL allowsCellularAccess;

- (id<NJFileDownloaderTask>)downloadRequest:(NSURLRequest *)request
                                     toPath:(NSString *)resultPath
                                 completion:(void(^)(NSError *error))completionHandler;


- (id<NJFileDownloaderTask>)downloadRequest:(NSURLRequest *)request
                                     toPath:(NSString *)resultPath
                                   progress:(void (^)(id<NJFileDownloaderTask> downloadTask))downloadProgressHandler
                                 completion:(void(^)(NSError *error))completionHandler;

- (id<NJFileDownloaderTask>)downloadWithResumeData:(NSData *)resumeData
                                            toPath:(NSString *)resultPath
                                          progress:(void (^)(id<NJFileDownloaderTask> downloadTask))downloadProgressHandler
                                        completion:(void(^)(NSError *error))completionHandler;


+ (NSData *)getResumeData:(NSError *)error;

@end
