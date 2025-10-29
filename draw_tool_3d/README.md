# DrawTool3D

I made this tool as a workaround to Godot's inability to provide a line thickness when drawing in 3D. This tool can mimic thick lines using stretched
and thinned cubes.

It's not as performant as the alternatives. You can clear it and redraw lines every frame for debugging purposes, but re-drawing too many things every
frame may take a toll on performance.


## Quick Example:

```gdscript
func _ready() -> void:
    var dt := DrawTool3D.new()

    dt.transparent = true  # set it up BEFORE adding as child
    dt.on_top = true
    add_child(dt)

    dt.draw_line(Vector3(), Vector3(5,5,5), Color.GREEN, 2)
```
