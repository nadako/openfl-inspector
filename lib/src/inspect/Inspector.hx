package inspect;

import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Stage;
import openfl.display.Sprite;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.geom.Point;
import js.html.ArrayBuffer;
import haxe.io.Bytes;
import vdom.JQuery;

class SelectTool {
	var stage:Stage;
	var inspector:Inspector;
	var label:JQuery;
	var isActive:Bool;

	public function new(stage:Stage, inspector:Inspector, label:JQuery) {
		this.stage = stage;
		this.inspector = inspector;
		this.label = label;
		label.text("Select");
		isActive = false;
	}

	public function activate() {
		if (!isActive) {
			isActive = true;
			label.text("Selecting...");
			label.attr("disabled", "true");
			stage.addEventListener(MouseEvent.CLICK, onClick, true);
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onMove, true);
		}
	}

	function getObjectUnderCursor() {
		var objects = stage.getObjectsUnderPoint(new Point(stage.mouseX, stage.mouseY));
		return objects[0];
	}

	function onMove(e:MouseEvent) {
		e.preventDefault();
		e.stopImmediatePropagation();
		inspector.highlight(getObjectUnderCursor());
	}

	function onClick(e:MouseEvent) {
		stage.removeEventListener(MouseEvent.CLICK, onClick, true);
		stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMove, true);
		e.preventDefault();
		e.stopImmediatePropagation();
		isActive = false;
		label.text("Select");
		label.removeAttr("disabled");
		inspector.highlight(null);
		var selectedObject = getObjectUnderCursor();
		if (selectedObject != null) {
			inspector.select(selectedObject);
		}
	}
}

class Inspector extends vdom.Client {
	static var current:Inspector;

	var jroot:JQuery;
	var client:IO.Socket;
	var connected = false;
	var highlightBitmap:Bitmap;
	var hierarchy:Hierarchy;
	var stage:Stage;

	public function new(stage:Stage, host:String, port:Int) {
		super();
		this.stage = stage;

		var overlay = new Sprite();
		overlay.name = "Inspector overlay";

		highlightBitmap = new Bitmap(new BitmapData(1, 1, false, 0x0000FF));
		highlightBitmap.name = "Object highlight";
		highlightBitmap.alpha = 0.3;
		highlightBitmap.visible = false;
		overlay.addChild(highlightBitmap);

		stage.addChild(overlay);
		stage.addEventListener(Event.ADDED, function(e:Event) {
			if ((e.target : DisplayObject).parent == stage) {
				stage.setChildIndex(overlay, stage.numChildren);
			}
		});

		current = this;

		jroot = J(getRoot());

		var hierarchyDiv = jroot.query("<div>");
		hierarchyDiv.attr("id", "hierarchy");
		hierarchyDiv.appendTo(jroot);

		var selectObjectButton = jroot.query("<button>").appendTo(hierarchyDiv);

		var propertiesDiv = jroot.query("<div>");
		propertiesDiv.attr("id", "properties");
		propertiesDiv.appendTo(jroot);

		var properties = new Properties(propertiesDiv);
		hierarchy = new Hierarchy(stage, this, hierarchyDiv, properties);

		var selectTool = new SelectTool(stage, this, selectObjectButton);
		selectObjectButton.click(function(_) selectTool.activate());

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

	public function select(object:DisplayObject) {
		hierarchy.selectObject(object);
	}

	public function highlight(object:DisplayObject) {
		if (object == null) {
			highlightBitmap.visible = false;
		} else {
			highlightBitmap.visible = true;
			var bounds = object.getBounds(stage);
			highlightBitmap.x = bounds.x;
			highlightBitmap.y = bounds.y;
			highlightBitmap.width = bounds.width;
			highlightBitmap.height = bounds.height;
		}
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
	var objectNameElement:JQuery;

	public function new(object:DisplayObject, level:Int, container:JQuery, onAdded:DisplayObjectNode->Void, onClick:DisplayObjectNode->Void, onRemoved:DisplayObjectNode->Void, onOver:DisplayObjectNode->Void, onOut:DisplayObjectNode->Void) {
		this.object = object;
		this.level = level;

		onAdded(this);

		object.addEventListener(Event.REMOVED, function(e:Event) {
			if (e.target == object)
				remove();
		});

		element = container.query("<li>");
		element.appendTo(container);

		var expandContainer = element.query("<span>");
		expandContainer.addClass("expand");
		expandContainer.appendTo(element);

		var span = objectNameElement = container.query("<span>");
		span.addClass("object-name");
		span.appendTo(element);
		span.text(if (object.name == null) Std.string(object) else object.name);
		span.bind("mouseover", function(_) onOver(this));
		span.bind("mouseout", function(_) onOut(this));

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
				new DisplayObjectNode(doContainer.getChildAt(i), level + 1, ul, onAdded, onClick, onRemoved, onOver, onOut);
			}

			object.addEventListener(Event.ADDED, function(e:Event) {
				if ((e.target : DisplayObject).parent == object) {
					expand.show();
					new DisplayObjectNode(e.target, level + 1, ul, onAdded, onClick, onRemoved, onOver, onOut);
				}
			});
		}
	}

	public function setSelected(selected:Bool) {
		if (selected)
			objectNameElement.addClass("selected")
		else
			objectNameElement.removeClass("selected");
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
	var inspector:Inspector;

	var currectSelection:DisplayObjectNode;
	var nodes:Array<DisplayObjectNode>;

	public function new(stage:Stage, inspector:Inspector, root:JQuery, properties:Properties) {
		this.inspector = inspector;
		this.properties = properties;

		var container = root.query("<ul>");
		container.appendTo(root);

		nodes = [];
		new DisplayObjectNode(stage, 0, container, nodes.push, onObjectNodeClick, onObjectNodeRemoved, onObjectNodeMouseOver, onObjectNodeMouseOut);
	}

	function onObjectNodeMouseOver(node:DisplayObjectNode) {
		inspector.highlight(node.object);
	}

	function onObjectNodeMouseOut(node:DisplayObjectNode) {
		inspector.highlight(null);
	}

	public function selectObject(object:DisplayObject) {
		var node = Lambda.find(nodes, function(node) return node.object == object);
		if (node == null) return;
		onObjectNodeClick(node);
	}

	function onObjectNodeClick(node:DisplayObjectNode) {
		if (currectSelection != null) currectSelection.setSelected(false);
		currectSelection = node;
		node.setSelected(true);
		properties.showProperties(node.object);
	}

	function onObjectNodeRemoved(node:DisplayObjectNode) {
		nodes.remove(node);
		if (currectSelection == node) {
			properties.clear();
			currectSelection = null;
		}
	}
}

class Widget<T> {
	public var element(default,null):JQuery;

	public function new(factory:JQuery, value:T) {
		element = init(factory, value);
	}

	function init(factory:JQuery, value:T):JQuery throw "abstract";
}

class EditWidget<T> extends Widget<T> {
	var onChange:T->Void;

	public function new(factory, value, onChange) {
		super(factory, value);
		this.onChange = onChange;
	}
}

class Label extends Widget<String> {

	override function init(factory:JQuery, value:String) {
		var span = factory.query("<span>");
		span.text(value);
		return span;
	}
}

class TextEdit extends EditWidget<String> {
	override function init(factory:JQuery, value:String) {
		var input = factory.query("<input>");
		input.attr("type", "text");
		input.val(value);
		input.change(function(_) {
			onChange(input.getValue());
		});
		return input;
	}
}

class CheckBox extends EditWidget<Bool> {
	var checked:Bool;

	override function init(factory:JQuery, value:Bool) {
		var input = factory.query("<input>");
		input.attr("type", "checkbox");
		checked = value;
		if (value) input.attr("checked", "checked");
		input.change(function(_) {
			checked = !checked;
			onChange(checked);
		});
		return input;
	}
}

class NumberEdit extends EditWidget<Float> {
	public function new(factory, value, onChange, step = 1.0) {
		super(factory, value, onChange);
		element.attr("step", Std.string(step));
	}

	override function init(factory:JQuery, value:Float) {
		var input = factory.query("<input>");
		input.attr("type", "number");
		input.val(value);
		input.change(function(_) {
			onChange(Std.parseFloat(input.getValue()));
		});
		return input;
	}
}

class Properties {
	var table:JQuery;

	public function new(parent:JQuery) {
		table = parent.query("<table>");
		table.appendTo(parent);
	}

	public function clear() {
		table.children().remove();
	}

	public function showProperties(object:DisplayObject) {
		clear();

		addProperty("type", new Label(table, Type.getClassName(Type.getClass(object))));
		addProperty("name", new TextEdit(table, object.name, function(v) object.name = v)); // TODO: update the name in hierarchy
		addProperty("x", new NumberEdit(table, object.x, function(v) object.x = v));
		addProperty("y", new NumberEdit(table, object.y, function(v) object.y = v));
		addProperty("scaleX", new NumberEdit(table, object.scaleX, function(v) object.scaleX = v));
		addProperty("scaleY", new NumberEdit(table, object.scaleY, function(v) object.scaleY = v));
		addProperty("visible", new CheckBox(table, object.visible, function(visible) object.visible = visible));
		addProperty("alpha", new NumberEdit(table, object.alpha, function(alpha) object.alpha = alpha, 0.1));
		addProperty("cacheAsBitmap", new CheckBox(table, object.cacheAsBitmap, function(cache) object.cacheAsBitmap = cache));

		switch Std.instance(object, openfl.text.TextField) {
			case null:
			case tf:
				addProperty("text", new TextEdit(table, tf.text, function(v) tf.text = v));
		}
	}

	function addProperty<T>(name, widget:Widget<T>) {
		var tr = table.query("<tr>");
		tr.appendTo(table);

		var th = tr.query("<th>");
		th.appendTo(tr);
		th.text(name);

		var td = tr.query("<td>");
		td.appendTo(tr);
		widget.element.appendTo(td);
	}
}
