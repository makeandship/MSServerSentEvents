var http = require('http'),
    fs = require('fs');

var server = http.createServer(function(request, response) {
	var parts = request.url.split('/');

	if (parts[1] === 'stream-events') {
	    response.writeHead(200, {
	        'Access-Control-Allow-Origin': 'http://localhost',
	        "Content-Type": "text/event-stream",
	        "Connection": "keep-alive"
	    });
	    response.write('\
: a comment (ignored)\n\
this line will be ignored since there is no field and the line itself is not a field\n\
field: an unknown field that will be ignored\n\
:another commment\n\
\n\
data : this line will be ignored since there is a space after data\n\
\n\
data\n\
data:\n\
data\n\
: dispatch event with two newlines\n\
\n\
data: simple\n\
\n\
data: spanning\n\
data:multiple\n\
data\n\
data: lines\n\
data\n\
\n\
id: 1\n\
data: id is 1\n\
\n\
data: id is still 1\n\
\n\
id\n\
data: no id\n\
\n\
event: open\n\
data: a message event with the name "open"\n\n');
		response.write('da');
		response.write('ta: a message event with the name "message"\n\n');
		response.write('data: a line ending with crlf\r\n\
data: a line with a : (colon)\n\
data: a line ending with cr\r\
\n\
retry: 10000\n\
: reconnection time set to 10 seconds\n\
\n\
retry: one thousand\n\
: ignored invalid reconnection time value\n\
\n\
retry\n\
: reset to ua default\n');
		response.end();
  	}
  	else if ( parts[1] === 'stream-json' ) {
		var interval;
		
		response.writeHead(200, {
			"Content-Type": "application/json",
			"Connection": "keep-alive" 
		});
	
		response.on('end', function(){
	        console.log("End received!");
	        if ( interval ) {
		        clearInterval(interval);
		        interval = null;
		    }
	    });

	    response.on('close', function(){
	        console.log("Close received!");
	        if ( interval ) {
		        clearInterval(interval);
		        interval = null;
		    }
	    });
			
		interval = setInterval(function () {
			console.log("sent…");
		}, 3000);
	}
}).on('connection', function(socket) {
	// not sure this is necessary
	// socket.setTimeout(10000);
}).listen(8080);

console.log("Server running at http://127.0.0.1:8080/");