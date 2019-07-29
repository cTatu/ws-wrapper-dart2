import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';

class WebSocketChannelWrapper {
  int _requestIds;
  Map<dynamic, StreamController> _channels;
  IOWebSocketChannel _socket;
  Completer _readyCompleter;
  Timer _connectionTimer;

  WebSocketChannelWrapper(String url,
      {Iterable<String> protocols, Map<String, dynamic> headers, Duration pingInterval,
      Timer connectionTimer}) :
        _socket = IOWebSocketChannel.connect(url, protocols: protocols,
                                                  headers:headers,
                                                  pingInterval:pingInterval),
        _requestIds = 0,
        _readyCompleter = Completer(),
        _channels = HashMap()
        {
          _connectionTimer = connectionTimer ?? Timer(Duration(seconds: 1), () => 
                                                        _readyCompleter.completeError(TimeoutException));
          _socket.stream.listen(_onData);
        }

  WebSocketChannelWrapper.fromSocket(WebSocket socket) :
        _socket = IOWebSocketChannel(socket);

  /// Future that completes when socket connect successfully
  /// 
  /// Throw `TimeoutException` when default Timer of 1 second
  // run out before the socket can connect
  Future get ready => _readyCompleter?.future;

  _socketSend(data, [int reqId]){
    Map<String, dynamic> packet = {'a': data};

    if (reqId != null)
      packet['i'] = reqId;

    _socket.sink.add(json.encode(packet));
  }

  Map _listToMap(String event, List args){
    Map<String, dynamic> data = {'0':event};
    
    args?.asMap()?.forEach((i, e) => data[(++i).toString()] = e);

    return data;
  }

  /// Send [args] to the server with [event] as channel
  emit(String event, [List args]) {
    var data = _listToMap(event, args);
    _socketSend(data);
  }

  /// Send the data extacly like `emit` but could 
  /// recieve response from the server in the form of Future.
  Future request(String event, [List args]) async {
    var data = _listToMap(event, args);
    _socketSend(data, _requestIds);

    Map res = await _on(_requestIds++).first;
    
    var id = res['i'];
    _channels[id].close();
    _channels[id] = null;

    var completer = Completer();

    if (res.containsKey('e')){
      completer.completeError(res['e']);
    }else if (res.containsKey('d')){
      completer.complete(res['d']);
    }

    return completer.future;
  }

  Stream _on(key){
    StreamController sc = StreamController();
    _channels[key] = sc;
    return sc.stream;
  }

  /// Returns listener on [event] name 
  Stream on(String event) => _on(event);

  /// Close the socket and send [closeCode] and [closeReason] to the server
  close([int closeCode, String closeReason]){
    _socket.sink.close(closeCode, closeReason);
    _channels.forEach((_, sc) => sc?.close());
    _channels = null;
  }

  _onData(data) {
    Map map = json.decode(data);
    
    if (map.containsKey('i'))
      _channels[map['i']].sink.add(map);
    else if (map.containsKey('a')){
      var key = map['a']['0'];

      if (key == 'connect'){
        _connectionTimer.cancel();
        _readyCompleter.complete();
      }else if (_channels.containsKey(key))
        _channels[key].sink.add(map['a']['1']);
    }
  }
}