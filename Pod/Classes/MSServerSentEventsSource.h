//
//  ServerSentEventsSource.h
//  MSServerSentEvents
//
//  Created by Simon Heys on 15/07/2015.
//  Copyright (c) 2015 Make and Ship Limited. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MSServerSentEvent : NSObject <NSCoding, NSCopying>
@property (nonatomic, copy) NSString *data;
@property (nonatomic, copy) NSString *lastEventId;
@property (nonatomic, copy) NSString *event;
@property (nonatomic) NSTimeInterval reconnectionTime;
@end

@interface MSServerSentEventsSource : NSObject
@property (nonatomic, readonly) NSTimeInterval reconnectionTime;
@property (nonatomic) BOOL isCancelled;
@property (nonatomic, strong, readonly) NSMutableURLRequest *request;
+ (instancetype)serverSentEventsSourceWithRequest:(NSMutableURLRequest *)request
    receive:(void (^)(MSServerSentEvent *event))receive
    completion:(void (^)(void))completion
    failure:(void (^)(NSError *error))failure;
- (instancetype)initWithRequest:(NSMutableURLRequest *)request
    receive:(void (^)(MSServerSentEvent *event))receive
    completion:(void (^)(void))completion
    failure:(void (^)(NSError *error))failure;
- (void)cancel;
- (void)setShouldExecuteAsBackgroundTaskWithExpirationHandler:(void (^)(void))handler;

- (NSUInteger)addListenerForEvent:(NSString *)event usingBlock:(void (^)(MSServerSentEvent *event))block;
- (void)removeEventListenerWithIdentifier:(NSUInteger)identifier;
- (void)removeAllListenersForEvent:(NSString *)event;

@end

