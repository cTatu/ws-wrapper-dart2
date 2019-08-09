import 'dart:async';
import 'package:websocket_channel_wrapper/websocket_channel_wrapper.dart';

const PORT = 42069;

main() {
  WebSocketChannelWrapper socket = WebSocketChannelWrapper('ws://192.168.0.18:$PORT',
                                              headers: {'id': '1234567890qwertyuiop'});

  print('Connecting...');

  var onReady = socket.onConnect.first;

  onReady.timeout(Duration(seconds: 5), onTimeout: () => print('Server could not be reach, trying to re-connect'));

  socket.onConnect.skip(1).listen((_) => print('Successful re-connection to server'));

  socket.onDone.listen((_) => print('Connection lost, trying to re-connect!'));

  onReady.then((_) { // [onConnect] It's called every time the WebSocket reconnect
    print('Connected!');

    socket.emit('msg', ['DART_WEBSOCKET_WRAPPER', 'Hello, World!']);

    socket.on('serverTime').listen((time) => print('Time: $time'));  // Time: 2019-07-29T14:00:32.635Z

    socket.request('userCount').then((n) => print('# users: $n'));   // # users: 1

    socket.request('checkError').catchError((e) => print(e));        // Yep, errors work

    Timer(Duration(minutes: 1), () {    // Close the socket after 1 minute
      var code = 1007, reason = 'break time';
      print('Close code: $code Reason: $reason');
      socket.close(code, reason);
    });
  });
}
