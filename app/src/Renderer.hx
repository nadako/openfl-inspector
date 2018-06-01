import electron.renderer.IpcRenderer;
import js.html.Uint8Array;
import haxe.io.Bytes;

class Renderer extends vdom.Server {
	function new() {
		super(js.Browser.document.getElementById("root"));
		IpcRenderer.on("message", function(_, data:Uint8Array) {
			onMessage(decodeMessage(Bytes.ofData(data.buffer)));
		});
	}

	override function send(msg:vdom.Answer) {
		var bytes = encodeAnswer(msg);
		IpcRenderer.send("message", new Uint8Array(bytes.getData()));
	}

	static function main() {
		new Renderer();
	}
}