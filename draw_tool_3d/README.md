# DrawTool3D

I made this tool as a workaround to Godot's inability to provide a line thickness when drawing in 3D. This tool can mimic thick lines using stretched and thinned cubes. You may need to adjust the `width_factor` property, depending on your project.

It's not as performant as the alternatives, though. You can draw many static lines, but re-drawing too many things every frame may take a toll on performance. And notably, wireframe spheres are quite slow.


## Quick Example:

```gdscript
func _ready() -> void:
    var dt := DrawTool3D.new()

    dt.transparent = true  # set it up BEFORE adding as child
    dt.on_top = true
    add_child(dt)

    dt.draw_line(Vector3(), Vector3(5,5,5), Color.GREEN, 2)
```
