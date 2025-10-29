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
#         DragPlane        (version 6)
#
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
class_name DragPlane
extends Node3D

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

## Will be true while an object is being dragged.
var is_dragging  : bool
## The point where the mouse raycast intersected the plane.
var intersection : Vector3


var _axis       : Axis = Axis.X
var _plane      : Plane
var _target     : Node3D
var _target_pos : Vector3
var _plane_pos  : Vector3


func _ready() -> void:
	name = "DragPlane"


func _calculate_plane() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if _axis == Axis.Y:
		var rot_y: float = camera.global_rotation.y
		var direction := Vector3.FORWARD.rotated(Vector3.UP, rot_y)#.normalized()
		_plane = Plane(direction, _target_pos)
	else:
		var cam_pos:Vector3 = camera.global_position
		if _axis < Axis.XY:
			var point := cam_pos
			if   _axis == Axis.X: point.x = _plane_pos.x
			elif _axis == Axis.Z: point.z = _plane_pos.z
			var direction := _plane_pos.direction_to(point)
			_plane = Plane(direction, _plane_pos)
		else:
			match _axis:
				Axis.XY: _plane = Plane(Vector3.FORWARD, _plane_pos)
				Axis.YZ: _plane = Plane(Vector3.RIGHT, _plane_pos)
				Axis.ZX: _plane = Plane(Vector3.UP, _plane_pos)


func _get_mouse_position_on_plane() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	var intersection_point: Variant = _plane.intersects_ray(ray_origin, ray_dir)
	return intersection_point if intersection_point else _plane_pos



#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

# 		Public API

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
## Initializes dragging mode based on [param position_], along the [param axis] axis.
## [br][br]
## The [param position_] must be in global space.
func start_dragging(position_: Vector3, axis: Axis) -> void:
	is_dragging = true
	_target_pos = position_
	_plane_pos = position_
	_axis = axis
	_calculate_plane()


## Initializes dragging based on the [param node] node, along
## the [param axis] axis.
## [br][br]
## This allows for automatic updating of the node's position while dragging.
func start_dragging_node(node: Node3D, axis:int) -> void:
	_target = node
	start_dragging(_target.global_position, axis)


## Ends dragging mode.
func stop_dragging() -> void:
	is_dragging = false


## Call this in [method Node._unhandled_input] (when the mouse moves) or in
## [method Node._physics_process], in order to calculate the plane and the
## intersection position.
## [br][br]
## If a target object was provided in [method start_dragging_node], then its
## position will be automatically updated here.
func compute_intersection() -> void:
	_calculate_plane()
	intersection = _get_mouse_position_on_plane()
	if _target:
		set_target_position(_target)


## Sets the correct position on the [param node] dragged object. If you need
## more control over how this is applied, you can access the 'intersection'
## property directly instead.
func set_target_position(node: Node3D) -> void:
	var pos := node.global_position
	match _axis:
		Axis.X:  pos = Vector3(intersection.x, pos.y,          pos.z)
		Axis.Y:  pos = Vector3(pos.x,          intersection.y, pos.z)
		Axis.Z:  pos = Vector3(pos.x,          pos.y,          intersection.z)
		Axis.XY: pos = Vector3(intersection.x, intersection.y, pos.z)
		Axis.YZ: pos = Vector3(pos.x,          intersection.y, intersection.z)
		Axis.ZX: pos = Vector3(intersection.x, pos.y,          intersection.z)
	node.global_position = pos
