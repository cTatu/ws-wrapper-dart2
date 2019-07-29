import 'dart:async';
import 'package:websocket_channel_wrapper/websocket_channel_wrapper.dart';

main() {
  WebSocketChannelWrapper socket = WebSocketChannelWrapper('ws://192.168.0.18:30000',
                                              headers: {'id': '1234567890qwertyuiop'});

  print('Connecting...');

  socket.ready.then((_) {
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
