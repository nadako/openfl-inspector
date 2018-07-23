import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.events.KeyboardEvent;

class Main extends Sprite {
	public function new() {
		super();

		name = "main";

		var y = 0;
		function addShape(name, color) {
			var s = new openfl.display.Sprite();
			s.name = name;
			s.graphics.beginFill(color, 1);
			s.graphics.drawRect(0, 0, 50, 50);
			s.graphics.endFill();
			s.y = y;
			y += 55;
			s.cacheAsBitmap = true;
			s.addEventListener(MouseEvent.CLICK, function(_) {
				removeChild(s);
			});
			addChild(s);
		}

		addShape("redbox", 0xFF0000);
		addShape("greenbox", 0x00FF00);
		addShape("bluebox", 0x0000FF);

		stage.addEventListener(KeyboardEvent.KEY_DOWN, function(_) {
			addShape("new box at " + y, Std.random(0xFFFFFF));
		});

		new inspect.Inspector(stage, "localhost", 8000);
	}
}
