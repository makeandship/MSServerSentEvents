//
//  ServerSentEventsSourceTestCase.m
//  MSServerSentEvents
//
//  Created by Simon Heys on 15/07/2015.
//  Copyright (c) 2015 Make and Ship Limited. All rights reserved.
//

#import "MSServerSentEventsSourceTestCase.h"
#import "MSServerSentEventsSource.h"
#import "Expecta.h"

@implementation MSServerSentEventsSourceTestCase

- (void)setUp
{
    [super setUp];
    [Expecta setAsynchronousTestTimeout:5.0];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testServerSentEventsSource
{
    __block NSMutableArray *messages = [NSMutableArray new];
    __block BOOL didReceiveMessageEventWithListener = NO;
    __block BOOL didReceiveOpenEventWithListener = NO;
    __block BOOL didReceiveWildcardEventWithListener = NO;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/stream-events/"]];

    MSServerSentEventsSource *serverSentEventsSource = [[MSServerSentEventsSource alloc] initWithRequest:request receive:^(MSServerSentEvent *event) {
        NSLog(@"received:%@",event);
        [messages addObject:event];
    }
    completion:^{
        NSLog(@"closed");
    }
    failure:^(NSError *error) {
        NSLog(@"error:%@",error);
    }];
    
    [serverSentEventsSource addListenerForEvent:@"open" usingBlock:^(MSServerSentEvent *event) {
        NSLog(@"received open event");
        didReceiveOpenEventWithListener = YES;
    }];

    [serverSentEventsSource addListenerForEvent:@"message" usingBlock:^(MSServerSentEvent *event) {
        NSLog(@"received message event");
        didReceiveMessageEventWithListener = YES;
    }];

    [serverSentEventsSource addListenerForEvent:@"*" usingBlock:^(MSServerSentEvent *event) {
        NSLog(@"received * event");
        didReceiveWildcardEventWithListener = YES;
    }];

    expect(messages).will.haveCountOf(9);
    if ( 9 == messages.count ) {
        expect([((MSServerSentEvent *)messages[0]).data isEqualToString:@"\n\n"]).will.beTruthy();
        expect([((MSServerSentEvent *)messages[1]).data isEqualToString:@"simple"]).will.beTruthy();
        expect([((MSServerSentEvent *)messages[2]).data isEqualToString:@"spanning\nmultiple\n\nlines\n"]).will.beTruthy();
        expect([((MSServerSentEvent *)messages[3]).data isEqualToString:@"id is 1"]).will.beTruthy();
        expect([((MSServerSentEvent *)messages[3]).lastEventId isEqualToString:@"1"]).will.beTruthy();
        expect([((MSServerSentEvent *)messages[4]).data isEqualToString:@"id is still 1"]).will.beTruthy();
        expect([((MSServerSentEvent *)messages[4]).lastEventId isEqualToString:@"1"]).will.beTruthy();
        expect([((MSServerSentEvent *)messages[5]).data isEqualToString:@"no id"]).will.beTruthy();
        expect([((MSServerSentEvent *)messages[5]).lastEventId isEqualToString:@""]).will.beTruthy();
        expect([((MSServerSentEvent *)messages[6]).data isEqualToString:@"a message event with the name \"open\""]).will.beTruthy();
        expect([((MSServerSentEvent *)messages[7]).data isEqualToString:@"a message event with the name \"message\""]).will.beTruthy();
        expect([((MSServerSentEvent *)messages[8]).data isEqualToString:@"a line ending with crlf\na line with a : (colon)\na line ending with cr"]).will.beTruthy();
    }
    expect(didReceiveOpenEventWithListener).will.beTruthy();
    expect(didReceiveMessageEventWithListener).will.beTruthy();

}

@end
