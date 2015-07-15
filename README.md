# MSServerSentEvents

[![CI Status](http://img.shields.io/travis/Simon Heys/MSServerSentEvents.svg?style=flat)](https://travis-ci.org/Simon Heys/MSServerSentEvents)
[![Version](https://img.shields.io/cocoapods/v/MSServerSentEvents.svg?style=flat)](http://cocoapods.org/pods/MSServerSentEvents)
[![License](https://img.shields.io/cocoapods/l/MSServerSentEvents.svg?style=flat)](http://cocoapods.org/pods/MSServerSentEvents)
[![Platform](https://img.shields.io/cocoapods/p/MSServerSentEvents.svg?style=flat)](http://cocoapods.org/pods/MSServerSentEvents)

An Objective-C implementation of [Server-Sent Events](https://developer.mozilla.org/en-US/docs/Server-sent_events/Using_server-sent_events)

## Usage

Simply initialise an event source and then subscribe to receive events:

```objective-c
NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:@"http://127.0.0.1:8888/"];

MSServerSentEventsSource *serverSentEventsSource = [[MSServerSentEventsSource alloc] initWithRequest:request receive:^(MSServerSentEvent *event) {
	NSLog(@"received:%@",event);
}
completion:^{
	NSLog(@"closed");
}
failure:^(NSError *error) {
	NSLog(@"error:%@",error);
}];

[serverSentEventsSource addListenerForEvent:@"open" usingBlock:^(MSServerSentEvent *event) {
	NSLog(@"received open event");
}];

[serverSentEventsSource addListenerForEvent:@"message" usingBlock:^(MSServerSentEvent *event) {
	NSLog(@"received message event");
}];
```

## Installation

MSServerSentEvents is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "MSServerSentEvents"
```

## Author

Simon Heys, simon@makeandship.co.uk

## License

MSServerSentEvents is available under the MIT license. See the LICENSE file for more info.
