# Drag Planes

These classes facilitate dragging objects in 3D space. Use one or the other, not both. They're just different approaches to the exact same thing, and their usage is mostly identical. 


- `DragPlane` manually projects a ray from the mouse position, and uses a `Plane` to check for an intersection with the ray. Can be simpler to use than `DragPlaneShape`.

- `DragPlaneShape` is a `StaticBody3D` and detects ray picking using a `WorldBoundaryShape3D`. It may conflict with other `input_ray_pickable` nodes and require a more mindful usage. Since this uses a `CollisionShape3D`, it can also be visualized at runtime when turning on `Debug -> Visible Collision Shapes`. 

## Example Usage

The code for starting the dragging is the same for both.

```gdscript
# Assuming 'my_object' is 'input_ray_pickable' and its 'input_event' signal is connected
# (Although you can grab your objects in other ways if you prefer.)

func _on_my_object_input_event(camera:Node, event:InputEvent, event_position:Vector3, click_normal:Vector3, shape_idx:int) -> void:
	if event.is_action_pressed("editor_select"):
		my_object.input_ray_pickable = false  # stop receiving input events while dragging

		# use one of below (not both), and use the respective class to access the Axis enum 
		drag_plane.start_dragging(my_object.global_position, DragPlane.Axis.X)
		# drag_plane.start_dragging_node(my_object, DragPlane.Axis.X)
```

The rest of the code is slightly different.

### DragPlane:
```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_released("editor_select"):
		drag_plane.stop_dragging()
		my_object.input_ray_pickable = true
	
	if event is InputEventMouseMotion and drag_plane.is_dragging:
		drag_plane.compute_intersection()
		
		# if `start_dragging_node` was used, then don't use any of the lines below 
		drag_plane.set_target_position(my_object)
		# my_object.global_position.x = drag_plane.intersection.x  # set the respective axis that was specified above

```

### DragPlaneShape:
```gdscript
# Assuming the DragPlaneShape's 'input_event' is connected

func _on_drag_plane_input_event(camera:Node, event:InputEvent, event_position:Vector3, click_normal:Vector3, shape_idx:int) -> void:
	if event.is_action_released("editor_select"):
		drag_plane.stop_dragging()
		my_object.input_ray_pickable = true
	
	# if `start_dragging_node` was used, then don't use the lines below
	if event is InputEventMouseMotion:
		drag_plane.set_target_position(my_object)
		# my_object.global_position.x = drag_plane.intersection.x  # set the respective axis that was specified above

```
