//
//  ServerSentEventsSource.m
//  MSServerSentEvents
//
//  Created by Simon Heys on 15/07/2015.
//  Copyright (c) 2015 Make and Ship Limited. All rights reserved.
//

#import "MSServerSentEventsSource.h"
#import "EXTScope.h"

typedef void (^ServerSentEventBlock)(MSServerSentEvent *event);

@interface MSServerSentEventsSource () <NSURLConnectionDataDelegate>
@property (nonatomic,) NSTimeInterval reconnectionTime;
@property (nonatomic, strong) NSMutableData *streamedData;
@property (nonatomic, strong) NSString *eventNameBuffer;
@property (nonatomic, strong) NSString *dataBuffer;
@property (nonatomic, strong) NSString *lastEventId;
@property (nonatomic, copy) void (^receive)(MSServerSentEvent *event);
@property (nonatomic, copy) void (^completion)(void);
@property (nonatomic, copy) void (^failure)(NSError *error);
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableURLRequest *request;
@property (nonatomic, strong) NSMapTable *listenersKeyedByEvent;
@end

@implementation MSServerSentEventsSource

+ (instancetype)serverSentEventsSourceWithRequest:(NSMutableURLRequest *)request
    receive:(void (^)(MSServerSentEvent *event))receive
    completion:(void (^)(void))completion
    failure:(void (^)(NSError *error))failure
{
    MSServerSentEventsSource *serverSentEventsSource = [[MSServerSentEventsSource alloc] initWithRequest:request receive:receive completion:completion failure:failure];
    return serverSentEventsSource;
}

- (instancetype)initWithRequest:(NSMutableURLRequest *)request
    receive:(void (^)(MSServerSentEvent *event))receive
    completion:(void (^)(void))completion
    failure:(void (^)(NSError *error))failure
{
    if (self = [super init]) {
        @weakify(self);
        [request setValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
        [request setValue:@"text/event-stream" forHTTPHeaderField:@"Accept"];
        self.request = request;
        self.streamedData = [NSMutableData new];
        self.lastEventId = @"";
        self.eventNameBuffer = @"";
        self.dataBuffer = @"";
        self.reconnectionTime = 2.0;
        self.isCancelled = NO;
        self.receive = receive;
        self.failure = failure;
        self.completion = completion;
        dispatch_async(dispatch_get_main_queue(), ^{
            @strongify(self);
            self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
            [self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
            [self.connection start];
        });
     }
    return self;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.streamedData appendData:data];
    [self parseEventStream];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.failure(error);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    self.completion();
}

- (void)cancel
{
    [self.connection cancel];
    self.isCancelled = YES;
}

- (void)setShouldExecuteAsBackgroundTaskWithExpirationHandler:(void (^)(void))handler
{
    if (!self.backgroundTaskIdentifier) {
        @weakify(self);
        self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            @strongify(self);
            if (handler) {
                handler();
            }
            if (self) {
                [self cancel];
                [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
                self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
            }
        }];
    }
}

- (NSCharacterSet *)newlineCharacterSet
{
    static NSCharacterSet *_newlineCharacterSet;
    if ( nil == _newlineCharacterSet ) {
        _newlineCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"\n"];
    }
    return _newlineCharacterSet;
}

- (void)parseEventStream
{
    NSString *eventStreamString = [[NSString alloc] initWithData:self.streamedData encoding:NSUTF8StringEncoding];
    NSScanner *scanner = [[NSScanner alloc] initWithString:eventStreamString];
    // we only scan for \n as we need to keep \r to pass tests
    scanner.charactersToBeSkipped = [NSCharacterSet characterSetWithCharactersInString:@"\r"];
    
    BOOL scanning = YES;
    NSInteger lastScannedLocation = 0;
    
    while (scanning) {
        NSString *lineString = nil;
        // we only scan for \n as we need to keep \r to pass tests
        scanning = [scanner scanUpToCharactersFromSet:[self newlineCharacterSet] intoString:&lineString];
        if ( scanning ) {
            if ( scanner.scanLocation == eventStreamString.length ) {
                // got to the end; concatentate next time
            }
            else {
                [self parseEventStreamLineString:lineString];
            }
            if ( !scanner.isAtEnd ) {
                lastScannedLocation = scanner.scanLocation;
            }
        }
        // scan empty line?
        scanning = [scanner scanCharactersFromSet:[self newlineCharacterSet] intoString:&lineString];
        if ( scanning ) {
            if ( lineString.length > 1 ) {
                // more than one new line, spec says send the event
                [self dispatchEvent];
            }
            if ( !scanner.isAtEnd ) {
                lastScannedLocation = scanner.scanLocation;
            }
        }
    }
    if ( 0 == lastScannedLocation ) {
        // didn't consume anything, so keep all the data"
    }
    else  {
        [self.streamedData replaceBytesInRange:NSMakeRange(0, lastScannedLocation) withBytes:NULL length:0];
    }
}

// an implementation of the spec
// http://www.w3.org/TR/2009/WD-eventsource-20091029/
// webkit version is at
// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/EventSource.cpp

- (void)parseEventStreamLineString:(NSString *)eventStreamLineString
{
    if ( 0 == eventStreamLineString.length ) {
        return;
    }
    if ( [eventStreamLineString hasPrefix:@":"] ) {
        // comment, ignore?
        return;
    }
    NSString *field = nil, *value = nil;
    if ( NSNotFound != [eventStreamLineString rangeOfString:@":"].location ) {
        NSScanner *scanner = [[NSScanner alloc] initWithString:eventStreamLineString];
        [scanner scanUpToString:@":" intoString:&field];
        [scanner scanString:@":" intoString:nil];
        // we treat \r and \n as newline in this case
        [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&value];
        if ( [value hasPrefix:@" "] ) {
            value = [value substringFromIndex:1];
        }
    }
    else {
        // if there is no : then use the whole line as the field value
        field = eventStreamLineString;
        value = @"";
    }
    if ( [field isEqualToString:@"event"] ) {
        self.eventNameBuffer = value;
    }
    else if ( [field isEqualToString:@"data"] ) {
        if ( nil == value ) {
            self.dataBuffer = [self.dataBuffer stringByAppendingString:@"\n"];
        }
        else {
            self.dataBuffer = [self.dataBuffer stringByAppendingString:[NSString stringWithFormat:@"%@\n",value]];
        }
    }
    else if ( [field isEqualToString:@"id"] ) {
        self.lastEventId = value;
    }
    else if ( [field isEqualToString:@"retry"] ) {
        NSCharacterSet *nonNumericSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
        if ( NSNotFound != [value rangeOfCharacterFromSet:nonNumericSet].location ) {
            // retry value contains non decimal digits, ignoring
        }
        else {
            self.reconnectionTime = [value doubleValue] / 1000.0;
        }
    }
}

- (void)dispatchEvent
{
    if ( [self.dataBuffer hasSuffix:@"\n"] ) {
        self.dataBuffer = [self.dataBuffer substringToIndex:self.dataBuffer.length-1];
    }
    if ( nil == self.dataBuffer || [[NSNull null] isEqual:self.dataBuffer] || 0 == self.dataBuffer.length ) {
        self.dataBuffer = @"";
        self.eventNameBuffer = @"";
        return;
    }
    
    /*
    From the spec;
    Otherwise, create an event that uses the MessageEvent interface, with the event name message, which does not bubble, is not cancelable, and has no default action.
    
    so I think this means if the event name is still empty, we set it to 'message'
    
    this fits the test case where we need to receive an event with the name 'message'
    */
    
    MSServerSentEvent *event = [MSServerSentEvent new];
    event.data = self.dataBuffer;
    event.lastEventId = self.lastEventId;
    event.reconnectionTime = self.reconnectionTime;
    if ( self.eventNameBuffer && self.eventNameBuffer.length ) {
        event.event = self.eventNameBuffer;
    }
    else {
        event.event = @"message";
    }
    
    self.dataBuffer = @"";
    self.eventNameBuffer = @"";
    
    if ( self.receive ) {
        self.receive(event);
    }

    if ( event.event && event.event.length ) {
        @weakify(self);
        NSArray *allKeys = [[self.listenersKeyedByEvent keyEnumerator] allObjects];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%@ LIKE self",event.event];
        NSArray *matchingKeys = [allKeys filteredArrayUsingPredicate:predicate];
        [matchingKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
            @strongify(self);
            NSMutableDictionary *listenersKeyedByIdentifier = [self.listenersKeyedByEvent objectForKey:key];
            for ( NSNumber *identifier in listenersKeyedByIdentifier ) {
                ServerSentEventBlock block = listenersKeyedByIdentifier[identifier];
                if (block) {
                    block(event);
                }
            }
        }];
    }
}

// ____________________________________________________________________________________________________ listeners

#pragma mark - listeners

- (NSMapTable *)listenersKeyedByEvent
{
    if ( nil == _listenersKeyedByEvent ) {
        _listenersKeyedByEvent = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsCopyIn valueOptions:NSPointerFunctionsStrongMemory capacity:100];
    }
    return _listenersKeyedByEvent;
}

- (NSUInteger)addListenerForEvent:(NSString *)event usingBlock:(void (^)(MSServerSentEvent *event))block
{
    NSMutableDictionary *mutableListenersKeyedByIdentifier = [self.listenersKeyedByEvent objectForKey:event];
    if (!mutableListenersKeyedByIdentifier) {
        mutableListenersKeyedByIdentifier = [NSMutableDictionary dictionary];
    }

    NSUInteger identifier = [[NSUUID UUID] hash];
    mutableListenersKeyedByIdentifier[@(identifier)] = [block copy];
    
    [self.listenersKeyedByEvent setObject:mutableListenersKeyedByIdentifier forKey:event];

    return identifier;
}

- (void)removeEventListenerWithIdentifier:(NSUInteger)identifier
{
    NSEnumerator *enumerator = [self.listenersKeyedByEvent keyEnumerator];
    id event = nil;
    while ((event = [enumerator nextObject])) {
        NSMutableDictionary *mutableListenersKeyedByIdentifier = [self.listenersKeyedByEvent objectForKey:event];
        if ([mutableListenersKeyedByIdentifier objectForKey:@(identifier)]) {
            [mutableListenersKeyedByIdentifier removeObjectForKey:@(identifier)];
            [self.listenersKeyedByEvent setObject:mutableListenersKeyedByIdentifier forKey:event];
            return;
        }
    }
}

- (void)removeAllListenersForEvent:(NSString *)event
{
    [self.listenersKeyedByEvent removeObjectForKey:event];
}

@end


@implementation MSServerSentEvent

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@> \n", [self class]];
    [text appendFormat:@"\tevent: %@\n", self.event];
    [text appendFormat:@"\tlastEventId: %@\n", self.lastEventId];
    [text appendFormat:@"\treconnectionTime: %@\n", @(self.reconnectionTime)];
    [text appendFormat:@"\tdata: %@\n", self.data];
    return text;
}

#pragma mark - NSCoding, NSCopying

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (!self) {
        return nil;
    }

    self.event = [aDecoder decodeObjectForKey:@"event"];
    self.lastEventId = [aDecoder decodeObjectForKey:@"lastEventId"];
    self.data = [aDecoder decodeObjectForKey:@"data"];
    self.reconnectionTime = [aDecoder decodeDoubleForKey:@"reconnectionTime"];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.event forKey:@"event"];
    [aCoder encodeObject:self.lastEventId forKey:@"lastEventId"];
    [aCoder encodeObject:self.data forKey:@"data"];
    [aCoder encodeDouble:self.reconnectionTime forKey:@"reconnectionTime"];
}

- (id)copyWithZone:(NSZone *)zone
{
    MSServerSentEvent *event = [[[self class] allocWithZone:zone] init];
    event.event = self.event;
    event.lastEventId = self.lastEventId;
    event.data = self.data;
    event.reconnectionTime = self.reconnectionTime;
    return event;
}

@end
