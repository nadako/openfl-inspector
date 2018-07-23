package inspect;

import openfl.events.Event;
import openfl.display.Stage;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import js.html.ArrayBuffer;
import haxe.io.Bytes;
import vdom.JQuery;

class Inspector extends vdom.Client {
	static var current:Inspector;

	var jroot:JQuery;
	var client:IO.Socket;
	var connected = false;

	public function new(stage:Stage, host:String, port:Int) {
		super();

		current = this;

		jroot = J(getRoot());

		var hierarchyDiv = jroot.query("<div>");
		hierarchyDiv.attr("id", "hierarchy");
		hierarchyDiv.appendTo(jroot);

		var propertiesDiv = jroot.query("<div>");
		propertiesDiv.attr("id", "properties");
		propertiesDiv.appendTo(jroot);

		var properties = new Properties(propertiesDiv);
		new Hierarchy(stage, hierarchyDiv, properties);

		client = IO.io('http://$host:$port');
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

class Expand {
	var element:JQuery;
	var expanded:Bool = false;
	var onExpand:Bool->Void;

	public function new(parent:JQuery, onExpand:Bool->Void, expanded:Bool) {
		this.onExpand = onExpand;
		element = parent.query("<i>");
		element.addClass("fas");
		element.appendTo(parent);
		element.click(onClick);
		hide();
		if (expanded) expand() else collapse();
	}

	public function hide() {
		element.addClass("hidden");
	}

	public function show() {
		element.removeClass("hidden");
	}

	function expand() {
		expanded = true;
		element.removeClass("fa-angle-right");
		element.addClass("fa-angle-down");
		onExpand(true);
	}

	function collapse() {
		expanded = false;
		element.removeClass("fa-angle-down");
		element.addClass("fa-angle-right");
		onExpand(false);
	}

	function onClick(_) {
		if (!expanded) expand() else collapse();
	}
}

class DisplayObjectNode {
	public var object(default,null):DisplayObject;

	var element:JQuery;
	var childrenUL:JQuery;
	var onRemoved:DisplayObjectNode->Void;
	var level:Int;

	public function new(object:DisplayObject, level:Int, container:JQuery, onClick:DisplayObjectNode->Void, onRemoved:DisplayObjectNode->Void) {
		this.object = object;
		this.level = level;

		object.addEventListener(Event.REMOVED, function(e:Event) {
			if (e.target == object)
				remove();
		});

		element = container.query("<li>");
		element.appendTo(container);

		var expandContainer = element.query("<span>");
		expandContainer.addClass("expand");
		expandContainer.appendTo(element);

		var span = container.query("<span>");
		span.addClass("object-name");
		span.appendTo(element);
		span.text(if (object.name == null) Std.string(object) else object.name);

		span.click(function(_) onClick(this));

		this.onRemoved = onRemoved;

		var doContainer = Std.instance(object, DisplayObjectContainer);
		if (doContainer != null) {
			var ul = childrenUL = element.query("<ul>");
			ul.appendTo(element);

			var expanded = level < 2;
			var expand = new Expand(expandContainer, onExpand, expanded);

			var numChildren = doContainer.numChildren;
			if (numChildren > 0)
				expand.show();

			for (i in 0...numChildren) {
				new DisplayObjectNode(doContainer.getChildAt(i), level + 1, ul, onClick, onRemoved);
			}

			object.addEventListener(Event.ADDED, function(e:Event) {
				if ((e.target : DisplayObject).parent == object) {
					expand.show();
					new DisplayObjectNode(e.target, level + 1, ul, onClick, onRemoved);
				}
			});
		}
	}

	function onExpand(expand:Bool) {
		childrenUL.style("display", if (expand) "block" else "none");
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

		new DisplayObjectNode(stage, 0, container, onObjectNodeClick, onObjectNodeRemoved);
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

	var table:JQuery;

	public function new(parent:JQuery) {
		table = parent.query("<table>");
		table.appendTo(parent);
	}

	public function clear() {
		table.children().remove();
		currentObject = null;
	}

	public function showProperties(object:DisplayObject) {
		clear();

		currentObject = object;

		function addProperty(name, value) {
			var tr = table.query("<tr>");
			tr.appendTo(table);

			var th = tr.query("<th>");
			th.appendTo(tr);
			th.text(name);

			var td = tr.query("<td>");
			td.appendTo(tr);
			td.text(value);
		}

		addProperty("type", Type.getClassName(Type.getClass(object)));
		addProperty("name", object.name);
		addProperty("x", Std.string(object.x));
		addProperty("y", Std.string(object.y));
		addProperty("scaleX", Std.string(object.scaleX));
		addProperty("scaleY", Std.string(object.scaleY));
		addProperty("visible", Std.string(object.visible));
		addProperty("alpha", Std.string(object.alpha));
		addProperty("cacheAsBitmap", Std.string(object.cacheAsBitmap));
	}
}
