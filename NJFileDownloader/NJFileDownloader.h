//
//  NJFileDownloader.h
//  NJFileDownloader-ios
//
//  Created by 念纪 on 16/5/18.
//  Copyright © 2016年 nianji. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NJFileDownloaderTask <NSObject>

- (double)fractionCompleted;

- (void)pause;
- (void)resume;
- (void)cancel;

@end

@interface NJFileDownloader : NSObject

@property (nonatomic, strong) NSOperationQueue *callbackQueue;  //default is main queue

- (id<NJFileDownloaderTask>)downloadRequest:(NSURLRequest *)request
                                     toPath:(NSString *)resultPath
                                 completion:(void(^)(NSError *error))completionHandler;


- (id<NJFileDownloaderTask>)downloadRequest:(NSURLRequest *)request
                                     toPath:(NSString *)resultPath
                                   progress:(void (^)(id<NJFileDownloaderTask> downloadTask))downloadProgressHandler
                                 completion:(void(^)(NSError *error))completionHandler;


@end
