import 'dart:async';
import 'dart:io';
import 'package:websocket_channel_wrapper/websocket_channel_wrapper.dart';

const PORT = 42069;

main() {
  WebSocketChannelWrapper socket = WebSocketChannelWrapper('ws://192.168.0.18:$PORT',
                                              headers: {'id': '1234567890qwertyuiop'});

  print('Connecting...');

  var onReady = socket.onConnect.first;

  onReady.timeout(Duration(seconds: 5), onTimeout: () => print('Server could not be reach, trying to re-connect'));

  socket.onConnect.skip(1).listen((_) => print('Successful re-connection to server'));

  socket.onDone.listen((_) => print(socket.autoReconnect ? 'Connection lost, trying to re-connect!' : 'Connection ended!'));

  onReady.then((_) async { // [onConnect] It's called every time the WebSocket reconnect
    print('Connected!');

    socket.emit('msg', ['DART_WEBSOCKET_WRAPPER', 'Hello, World!']);

    socket.on('serverTime').listen((time) => print('Time: $time'));  // Time: 2019-07-29T14:00:32.635Z

    socket.request('userCount').then((n) => print('# users: $n'));   // # users: 1

    socket.request('checkError').catchError((e) => print(e));        // Yep, errors work

    var filename = '/path/to/file/image.jpg';
    sendFile(filename, socket);   // Send binary file over socket

    Timer(Duration(seconds: 10), () {    // Close the socket after 1 minute
      var reason = 'break time';
      print('Close reason: $reason');
      socket.close(closeReason: reason);
    });
  });
}

sendFile(String filename, socket) async {
  var image = File(filename);
  var contents = await image.readAsBytes();

  final stopwatch = Stopwatch()..start();   // Start timer to measure speed
  
  socket.request('transferFile', [filename, contents]).then((_) { // Send first file name then the bytes

    final speed = contents.length / stopwatch.elapsedMicroseconds;
    print('File sended in ${stopwatch.elapsed} at $speed MB/s');  // File sended in 0:00:00.058191 at 1.63 MB/s

  }).catchError((e) => print(e));
}
