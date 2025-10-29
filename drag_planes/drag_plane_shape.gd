#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
# MIT License
#
# Copyright (c) 2025 Skaruts
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#
#         DragPlaneShape        (version 18)
#
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
class_name DragPlaneShape
extends StaticBody3D

##
## A utility node for detecting mouse dragging in 3D space.
## [br][br]
##
## A helper node for detecting mouse dragging of 3D objects, to allow moving
## them in one or more axes.
## [br][br]
##

## The axes that an object can be dragged on.
enum Axis { X, Y, Z, XY, YZ, ZX }

## The point where the mouse raycast intersected the plane.
var intersection : Vector3


var _target   : Node3D
var _axis     : int
var _collider : CollisionShape3D



func _ready() -> void:
	_collider = CollisionShape3D.new()
	_collider.shape = WorldBoundaryShape3D.new()
	add_child(_collider)
	stop_dragging()


func _input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	intersection = event_position
	_adjust_facing()
	if _target:
		set_target_position(_target)


func _adjust_facing() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()

	if _axis == Axis.Y:
		_collider.rotation.y = camera.owner.get_camera_pivot().rotation.y
	else:
		var cam_pos:Vector3 = camera.owner.global_position
		if _axis < Axis.XY:
			var point := cam_pos
			if   _axis == Axis.X: point.x = _collider.global_position.x
			elif _axis == Axis.Z: point.z = _collider.global_position.z

			if not point.is_equal_approx(_collider.global_position):
				_collider.look_at(point, Vector3.UP)
		else:
			var plane: Plane
			match _axis:
				Axis.XY: plane = Plane.PLANE_XY if cam_pos.z > 0 else -Plane.PLANE_XY
				Axis.YZ: plane = Plane.PLANE_YZ if cam_pos.x > 0 else -Plane.PLANE_YZ
				Axis.ZX: plane = Plane.PLANE_XZ if cam_pos.y > 0 else -Plane.PLANE_XZ

			_collider.shape.plane = plane


# --- reference ---
# PLANE_YZ = Plane( 1, 0, 0, 0 ) -- A plane that extends in YZ axes (normal vector points +X).
# PLANE_XZ = Plane( 0, 1, 0, 0 ) -- A plane that extends in ZX axes (normal vector points +Y).
# PLANE_XY = Plane( 0, 0, 1, 0 ) -- A plane that extends in XY axes (normal vector points +Z).
# -----------------
func _set_axis(axis: int) -> void:
	if axis != _axis:
		_axis = axis
		match axis:
			Axis.X, Axis.Z, Axis.XY: _collider.shape.plane = -Plane.PLANE_XY
			Axis.Y:                  _collider.shape.plane = Plane.PLANE_XY
			Axis.YZ:                 _collider.shape.plane = Plane.PLANE_YZ
			Axis.ZX:                 _collider.shape.plane = Plane.PLANE_XZ



#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

#		Public API

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
## Initializes dragging mode based on [param position_], along the [param axis] axis.
## [br][br]
## The [param position_] must be in global space.
func start_dragging(position_: Vector3, axis:int) -> void:
	input_ray_pickable = true
	_collider.transform.basis = Basis()
	_collider.global_position = position_
	_set_axis(axis)
	_adjust_facing()


## Initializes dragging based on the [param node] node, along
## the [param axis] axis.
## [br][br]
## This allows for automatic updating of the node's position while dragging.
func start_dragging_node(node: Node3D, axis:int) -> void:
	_target = node
	start_dragging(_target.global_position, axis)


## Ends dragging mode.
func stop_dragging() -> void:
	input_ray_pickable = false
	_target = null


## Sets the correct position on the [param node] dragged object. If you need
## more control over how this is applied, you can access the 'intersection'
## property directly instead.
func set_target_position(node: Node3D) -> void:
	var pos := node.global_position
	match _axis:
		Axis.X:     pos = Vector3(intersection.x, pos.y,          pos.z)
		Axis.Y:     pos = Vector3(pos.x,          intersection.y, pos.z)
		Axis.Z:     pos = Vector3(pos.x,          pos.y,          intersection.z)
		Axis.XY:    pos = Vector3(intersection.x, intersection.y, pos.z)
		Axis.YZ:    pos = Vector3(pos.x,          intersection.y, intersection.z)
		Axis.ZX:    pos = Vector3(intersection.x, pos.y,          intersection.z)
	node.global_position = pos
