// Stores the active WebSocket socket between pages
let activeSocket = null;

export function setSocket(socket) {
  activeSocket = socket;
}

export function getSocket() {
  return activeSocket;
}

export function clearSocket() {
  if (activeSocket) {
    activeSocket.disconnect();
    activeSocket = null;
  }
}
