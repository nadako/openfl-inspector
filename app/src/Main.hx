import electron.main.App;
import electron.main.BrowserWindow;
import electron.main.IpcMain;
import js.node.socketio.Server;
import js.node.socketio.Socket;
import js.html.ArrayBuffer;
import js.html.Uint8Array;

class InspectorWindow {
	var socket:Socket;
	var window:BrowserWindow;

	public function new(socket) {
		this.socket = socket;

		window = new BrowserWindow({width: 800, height: 600});
		window.loadFile("index.html");
		window.on("close", function(_) {
			socket.disconnect(true);
			socket = null;
		});

		function send(msg) {
			window.webContents.send("message", msg);
		}

		var pendingMessages = [];
		window.webContents.once("did-finish-load", function() {
			for (msg in pendingMessages)
				send(msg);
			pendingMessages = null;
		});

		socket.on("disconnect", function() {
			window.close();
			socket = null;
		});

		socket.on("error", function() {
			window.close();
			socket.disconnect(true);
			socket = null;
		});

		socket.on("message", function(data:ArrayBuffer) {
			var msg = new Uint8Array(data);
			if (pendingMessages != null) {
				pendingMessages.push(msg);
			} else
				send(msg);
		});

		IpcMain.on("message", function(event, data:Uint8Array) {
			if (!window.isDestroyed() && event.sender.id == window.webContents.id) {
				socket.emit("message", data.buffer);
			}
		});
	}
}

class Main {
	static function main() {
		var port = 8000;
		App.on("ready", function(_) {
			var server = new Server();
			server.listen(port);
			server.on("connection", function(socket:Socket) {
				new InspectorWindow(socket);
			});
		});
		App.on("window-all-closed", function(_) {}); // prevent quitting
	}
}
