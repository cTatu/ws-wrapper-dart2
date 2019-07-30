Wrapper for web_socket_channel package lightweight and isomorphic lib with socket.io-like event handling, Future-based requests. This wrapper implements the protocol for [this ws node wrapper](https://github.com/bminer/ws-wrapper).

**WARNING: server -> client requests are not sopported. If someone needs them open a PR**

## Usage

A simple usage example:

**Client side:**
```dart
import 'dart:async';
import 'package:websocket_channel_wrapper/websocket_channel_wrapper.dart';

main() {
  WebSocketChannelWrapper socket = WebSocketChannelWrapper('ws://192.168.0.18:30000',
                                              headers: {'id': '1234567890qwertyuiop'});

  print('Connecting...');

  socket.ready.listen((_) {
    print('Connected!');

    socket.emit('msg', ['DART_WEBSOCKET_WRAPPER', 'Hello, World!']);

    socket.on('serverTime').listen((time) => print('Time: $time'));  // Time: 2019-07-29T14:00:32.635Z

    socket.request('userCount').then((n) => print('# users: $n'));   // # users: 1

    socket.request('checkError').catchError((e) => print(e));        // Yep, errors work

    Timer(Duration(seconds: 5), () {    // Close the socket after 5 seconds
      var code = 1007, reason = 'break time';
      print('Close code: $code Reason: $reason');
      socket.close(code, reason);
    });
  
  }).catchError((_) => print('Connection timeout'));
}
```

**Server side:**
```js
const WebSocketServer = require("ws").Server,
      WebSocketWrapper = require("ws-wrapper");

var wss = new WebSocketServer({port: 30000});
var sockets = new Set();

wss.on("connection", (sckt, req) => {
    const socket = new WebSocketWrapper(sckt)
    sockets.add(socket)

    console.log('New socket connected')
    socket.emit('serverTime', new Date())  // Send data to client on connect
    
    socket.on("msg", function(from, msg) {
        console.log(`Received message from ${from}: ${msg}`) // Received message from DART_WEBSOCKET_WRAPPER: Hello, World!
	});

    socket.on("userCount", () => {  // Request
		return sockets.size;
    });
    
    socket.on("checkError", () => { // Request rejecting the Promise
        throw 'Yep, errors work'
    })

    socket.on("disconnect", (event) => {
        console.log(`REASON: ${event.reason} CODE: ${event.code}`) // REASON: break time    CODE: 1007
        sockets.delete(socket);
	});
})
```
