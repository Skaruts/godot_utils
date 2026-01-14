# Drag Planes

The purpose of this tool is to drag objects in 3D space using the mouse. Use one or the other, not both. They're just different approaches to the exact same thing, and their usage is identical.


- `DragPlaneEquation` projects a ray from the mouse position, and uses a `Plane` object to check for an intersection with the ray.

- `DragPlaneShape` is a `StaticBody3D` and detects ray picking using a `WorldBoundaryShape3D`. It may conflict with other `input_ray_pickable` nodes and require a more mindful usage.

The first one has the slight advantage that it only involves a single node and it probably has no picking conflicts, but the second one can be visualized at runtime when `Debug -> Visible Collision Shapes` is enabled.


## Example Usage

Create a `DragPlaneEquation` or `DragPlaneShape` object just like you would
create any other node, either by placing it in the scene tree, or through code.


```gdscript
var drag_plane: DragPlaneShape

func _ready() -> void:
	drag_plane = DragPlaneShape.new()
	add_child(drag_plane)
```

### Starting to drag
The code for starting the dragging is the same for both.

You can grab your objects manually if you prefer, but the example here uses an `input_ray_pickable` object `my_object` which has its `input_event` signal connected to the function below. (Only the `event` parameter is used.)

```gdscript
func _on_my_object_input_event(camera: Node, event: InputEvent, event_position: Vector3, click_normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# turn off input events on the dragged object while it's being dragged
		my_object.input_ray_pickable = false

		# start dragging along one or two axes (use one or the other, not both)
		drag_plane.start_dragging(my_object.global_position, my_object.basis.x)
		drag_plane.start_dragging(my_object.global_position, my_object.basis.x, my_object.basis.z)

```

If you specify one axis, the dragging will be calculated along that single axis. If you specify two axes, the dragging will be calculated along the plane formed by those two axes.

To specify the dragging axes you can use the object's `basis` or `global_basis`, but you can also use other direction vectors of your choice, and they don't have to be related to a `Node3D`. Whatever you do with the dragging results is up to you.

###### Note: when using two axes, they are expected to be two perpendicular directions that represent a flat movement plane. The code internally uses a cross product to determine the facing of the plane, so it may still work with non-perpendicular vectors, as long as they're not pointing in the exact same direction. This hasn't been tested, though.


### Getting dragging results / stop dragging
The rest of the code is also the same for both, except one relies on `_unhandled_input` and the other can use the `_on_drag_plane_input_event` signal callback (and you must connect the signal to it).


```gdscript
# DragPlaneEquation
func _unhandled_input(event: InputEvent) -> void:

# DragPlaneShape
func _on_drag_plane_input_event(camera: Node, event: InputEvent, event_position: Vector3, click_normal: Vector3, shape_idx: int) -> void:

# code for either of the above
    if event is InputEventMouseButton and not event.pressed:
        my_object.input_ray_pickable = true
        drag_plane.stop_dragging()
    elif event is InputEventMouseMotion:
        if drag_plane.is_dragging:
            my_object.global_position = drag_plane.get_drag_position()
```
