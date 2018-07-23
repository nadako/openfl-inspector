package inspect;

import haxe.extern.Rest;
import haxe.Constraints.Function;

@:native("io")
extern class IO {
	@:selfCall static function io(url:String):Socket;

	static function __init__():Void {
		haxe.macro.Compiler.includeFile("inspect/socket.io.slim.js");
	}
}

extern class Socket {
	function emit(eventName:String, args:Rest<Any>):Socket;
	function on(eventName:String, callback:Function):Socket;
}
