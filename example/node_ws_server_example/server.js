const WebSocketServer = require("ws").Server
  , WebSocketWrapper = require("ws-wrapper");

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