import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:pedantic/pedantic.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketChannelWrapper {
  int _requestIds;
  bool _wasOpen = false, _autoReconnect = true;
  Map<dynamic, StreamController> _channels;
  IOWebSocketChannel _socket;
  StreamController _readyStream, _onDoneStream;
  Timer _reconnectTimer, _autoRecTimer;

  final double RECONNECT_VALUE_MIN = 1000, // 1 second
               RECONNECT_VALUE_MAX = 1000 * 60.0, // 1 minute
               RECONNECT_VALUE_FACTOR = 1.4;

  double _reconnectValue;
  var _url, _protocols, _headers, _pingInterval;

  WebSocketChannelWrapper(String url,
      {Iterable<String> protocols, Map<String, dynamic> headers, Duration pingInterval}) : _requestIds = 0,
                                _readyStream = StreamController(),
                                _onDoneStream = StreamController(),
                                _channels = HashMap()
      {
        _reconnectValue = RECONNECT_VALUE_MIN;
        _init(url, protocols: protocols, headers: headers, pingInterval: pingInterval);
      }

  _fromSocket(WebSocket socket) => IOWebSocketChannel(socket);

  _init(url, {protocols, headers, pingInterval, connectionTimer}) {
    _url = url;
    _protocols = protocols;
    _headers = headers;
    _pingInterval = pingInterval;

    WebSocket.connect(_url, headers: _headers, protocols: _protocols).then((ws) {
      ws.pingInterval = pingInterval;
      _socket = _fromSocket(ws);
      _socket.stream.listen(_onData, onDone: _onDone);
    }).catchError((e) => _reconnect());
  }

  /// Auto-reconnect using exponential back-off
  _reconnect () {
    if(!_autoReconnect){
      return;
    }

    if(_wasOpen) {
        _reconnectValue = RECONNECT_VALUE_MIN;
    }else {
        _reconnectValue = min<num>(_reconnectValue * RECONNECT_VALUE_FACTOR, RECONNECT_VALUE_MAX);
    }

    _reconnectTimer = Timer(Duration(milliseconds: _reconnectValue.round()), () => 
                          _init(_url, protocols: _protocols, headers: _headers, pingInterval: _pingInterval));
  }

  /// Stream that gets called every time the WebSocket connects
  /// including reconnect
  Stream get ready => _readyStream.stream;

  /// Gets called every time the WebSocket disconnect from the server.  
  /// On every call it will try to reconnect
  Stream get onDone => _onDoneStream.stream;

  _socketSend(data, [int reqId]){
    Map<String, dynamic> packet = {'a': data};

    if (reqId != null){
      packet['i'] = reqId;
    }

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
    unawaited(_channels[id].close());
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

  _onData(data) {
    Map map = json.decode(data);
    
    if (map.containsKey('i')){
      _channels[map['i']].sink.add(map);
    }else if (map.containsKey('a')){
      var key = map['a']['0'];

      if (key == 'connect'){
        _wasOpen = true;
        _readyStream.sink.add(null);
        _reconnectTimer?.cancel();
        _autoRecTimer?.cancel();
      }else if (_channels.containsKey(key)){
        _channels[key].sink.add(map['a']['1']);
      }
    }
  }

  _onDone() {
    _reconnect();
    _onDoneStream.sink.add(null);
    _wasOpen = false;
  }

  /// Close the socket and send [closeCode] and [closeReason] to the server
  close([int closeCode, String closeReason]){
    _autoReconnect = false;
    _channels.forEach((_, sc) => sc?.close());
    _socket.sink.close(closeCode, closeReason);
  }
}