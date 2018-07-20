package inspect;

import openfl.events.Event;
import openfl.display.Stage;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import js.html.ArrayBuffer;
import haxe.io.Bytes;
import js.node.socketio.Client;
import vdom.JQuery;

class Inspector extends vdom.Client {
	static var current:Inspector;

	var jroot:JQuery;
	var client:Client;
	var connected = false;

	public function new(stage:Stage, host:String, port:Int) {
		super();

		current = this;

		jroot = J(getRoot());

		var hierarchyDiv = jroot.query("<div>");
		hierarchyDiv.appendTo(jroot);

		var propertiesDiv = jroot.query("<div>");
		propertiesDiv.appendTo(jroot);

		var properties = new Properties(propertiesDiv);
		new Hierarchy(stage, hierarchyDiv, properties);

		client = new Client('http://$host:$port');
		client.on("connect", function(_) {
			connected = true;
			syncDom();
		});
		client.on("message", function(data:ArrayBuffer) {
			handle(decodeAnswer(haxe.io.Bytes.ofData(data)));
		});
	}

	override function sendBytes(bytes:haxe.io.Bytes) {
		if (!connected) return;
		client.emit("message", bytes.getData());
	}
}

class DisplayObjectNode {
	public var object(default,null):DisplayObject;

	var element:JQuery;

	public function new(object:DisplayObject, container:JQuery, onClick:DisplayObjectNode->Void) {
		this.object = object;

		element = container.query("<li>");
		element.appendTo(container);

		var span = container.query("<span>");
		span.appendTo(element);
		span.text(if (object.name == null) Std.string(object) else object.name);

		span.click(function(_) onClick(this));

		var doContainer = Std.instance(object, DisplayObjectContainer);
		if (doContainer != null) {
			var ul = element.query("<ul>");
			ul.appendTo(element);
			for (i in 0...doContainer.numChildren) {
				var child = doContainer.getChildAt(i);
				var node = new DisplayObjectNode(child, ul, onClick);

				child.addEventListener(Event.REMOVED, function(e:Event) {
					if (e.target == child)
						node.remove();
				});
			}
		}
	}

	public function remove() {
		element.remove();
	}
}

class Hierarchy {
	var properties:Properties;
	public function new(stage:Stage, root:JQuery, properties:Properties) {
		this.properties = properties;

		var container = root.query("<ul>");
		container.appendTo(root);

		new DisplayObjectNode(stage, container, onObjectNodeClick);
	}

	function onObjectNodeClick(node:DisplayObjectNode) {
		properties.showProperties(node.object);
	}
}

class Properties {
	var container:JQuery;

	public function new(container:JQuery) {
		this.container = container;
	}

	public function showProperties(object:DisplayObject) {
		container.children().remove();

		function addProperty(name, value) {
			var p = container.query("<div>");
			p.appendTo(container);
			p.text('$name: $value');
		}

		addProperty("type", Type.getClassName(Type.getClass(object)));
		addProperty("name", object.name);
		addProperty("x", Std.string(object.x));
		addProperty("y", Std.string(object.y));
	}
}