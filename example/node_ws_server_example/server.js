const WebSocketServer = require("ws").Server
  , WebSocketWrapper = require("ws-wrapper")
const fs = require('fs')

const PORT = 42069

var wss = new WebSocketServer({port: PORT});
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

  socket.on("transferFile", (filename, buffer) => {
    return new Promise((resolve, reject) => {
      fs.writeFile(filename, Buffer.from(buffer), function(err) { // Save binary data recieved to file
        if(err)
          reject(err)
        else{
          resolve(true)
          console.log('File received and saved!')
        }
      })
    })
  })

  socket.on("disconnect", (event) => {
      console.log(`REASON: ${event.reason} CODE: ${event.code}`) // REASON: break time    CODE: 1007
      sockets.delete(socket);
  });
})

console.log('Listening on port: ' + PORT)