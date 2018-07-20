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
	var onRemoved:DisplayObjectNode->Void;

	public function new(object:DisplayObject, container:JQuery, onClick:DisplayObjectNode->Void, onRemoved:DisplayObjectNode->Void) {
		this.object = object;

		object.addEventListener(Event.REMOVED, function(e:Event) {
			if (e.target == object)
				remove();
		});

		element = container.query("<li>");
		element.appendTo(container);

		var span = container.query("<span>");
		span.appendTo(element);
		span.text(if (object.name == null) Std.string(object) else object.name);

		span.click(function(_) onClick(this));

		this.onRemoved = onRemoved;

		var doContainer = Std.instance(object, DisplayObjectContainer);
		if (doContainer != null) {
			var ul = element.query("<ul>");
			ul.appendTo(element);

			for (i in 0...doContainer.numChildren) {
				new DisplayObjectNode(doContainer.getChildAt(i), ul, onClick, onRemoved);
			}

			object.addEventListener(Event.ADDED, function(e:Event) {
				if ((e.target : DisplayObject).parent == object) {
					new DisplayObjectNode(e.target, ul, onClick, onRemoved);
				}
			});
		}
	}

	function remove() {
		element.remove();
		if (onRemoved != null) onRemoved(this);
	}
}

class Hierarchy {
	var properties:Properties;
	public function new(stage:Stage, root:JQuery, properties:Properties) {
		this.properties = properties;

		var container = root.query("<ul>");
		container.appendTo(root);

		new DisplayObjectNode(stage, container, onObjectNodeClick, onObjectNodeRemoved);
	}

	function onObjectNodeClick(node:DisplayObjectNode) {
		properties.showProperties(node.object);
	}

	function onObjectNodeRemoved(node:DisplayObjectNode) {
		if (properties.currentObject == node.object)
			properties.clear();
	}
}

class Properties {
	public var currentObject(default,null):DisplayObject;

	var container:JQuery;

	public function new(container:JQuery) {
		this.container = container;
	}

	public function clear() {
		container.children().remove();
		currentObject = null;
	}

	public function showProperties(object:DisplayObject) {
		clear();

		currentObject = object;

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