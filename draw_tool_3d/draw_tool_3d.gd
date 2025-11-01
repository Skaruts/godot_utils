#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
# MIT License
#
# Copyright (c) 2021 Skaruts
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
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#        DrawTool3D (Godot 4)        (version 18 - WIP)
#
#
#    - Uses MultiMeshes for lines, cones, spheres, cubes...
#    - Uses an ImmediateMesh to draw faces more efficiently, since they don't
#      require a thickness.
#    - uses another ImmediateMesh to draw fallback lines, for when thick lines
#      disappear with distance
#    - Uses Label3D for text (may use TextMeshes in the future - need testing).
#    - optionally, if 'see_through_geometry' is true, a second-pass material
#      is used to render lines that go behind world meshes
#
#
#    This works by drawing instances of a MultiMesh cube or cylinder,
#    stretched to represent lines, and instances of MultiMesh spheres for
#    3D points. For each line AB, it scales an instance of the cube in one
#    axis to equal the distance from A to B, and then rotates it accordingly
#    using 'transform.looking_at()'.
#
#    Cylinders, however, are upright by default, so they have to be
#    manually rotated to compensate for this.
#
#    NOTE: I wrote the code for cylinders in Godot 3, and currently it isn't
#    working properly in Godot 4. It's best to keep '_USE_CYLINDERS_FOR_LINES'
#    set to 'false' for now. Using cylinders will result in some
#    lines being oriented wrong.
#
#    NOTE: stretching lines too far can have unexpected results. Seems to work
#    fine with 10,000 unit long lines, but at 100,000 units they become
#    jittery and also deformed, and will disapear when viewed from
#    certain angles.
#
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#   TODO:
#
#   - dynamically adjusting the 'instance_count' no longer works in Godot 4.3+
#     or so, because changing that value now clears the internal buffers.
#     . this sucks smelly shriveled balls...
#     . need to set a high-enough 'instance_count' by default, for now
#     . will need to cache all the lines or something, which will probably
#       make it slow af.
#
#   - draw quads
#   - draw polygons
#
#   - figure out how to create cylinders through code (and cones), in order
#     to create naturaly a rotated cylinder that can work properly.
#
#	- allow changing settings after adding as child?
#
#   - find out if long lines fail due to some bug in here
#
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#		Geometry Reference / Conventions  (numbers next to vertices are normalized xyz coords)
#
#               010           110                         Y
#   Vertices     a0 ---------- b1            Faces      Top    -Z
#           011 /  |      111 /  |                        |   North
#             e4 ---------- f5   |                        | /
#             |    |        |    |          -X West ----- 0 ----- East X
#             |   d3 -------|-- c2                      / |
#             |  /  000     |  / 100               South  |
#             h7 ---------- g6                      Z    Bottom
#              001           101                          -Y
#
#      Vertices 'd' and 'f' are the position/start-point of the cube, and
#      the end-point of the cube, respectively.
#
#      a b c d  --  North face
#      e f g h  --  South face
#
#
#   Faces (Quads/Triangles) / UVs
#         (u,v)       (u2,v)
#           a0 ------- b1
#            |  \      |
#            |      \  |
#           d3 ------- c2
#         (u,v2)      (u2,v2)
#
#
#   Trialngle ordering (per face):
#       vertices    a b c   a c d
#       indices     0 1 2   0 2 3
#
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

class_name DrawTool3D
extends Node3D


#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

# 		User settings (change BEFORE adding as child)
#       I'm not sure what happens if you change these in the inspector (not tested).

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#@export_subgroup("Settings")
## If true, a second pass material will makes visible lines behind world geometry
## using the [param backline_color] color.
@export var see_through_geometry := false

## The render priority for the materials. You can adjust this if you need
## to control the order in which multiple [DrawTool3D]s are drawn.
@export var render_priority     := 0  # base render_priority for the materials

## Use only a single color for all lines (and another single color for backlines,
## if applicable), instead of a color per line. If this is true, then colors
## passed into the drawing functions will be ignored.
@export var single_color        := false

## If true, the [DrawTool3D] will only use the fallback lines,
## with 1px thickness (using an ImmediateMesh).
@export var use_only_thin_lines := false

## The default line_thickness. This will be used when no thickness value is
## passed into the drawing functions.
@export var line_thickness := 1.0

## How thin must the unit-cube be in order to properly represent a line
## of thickness 1. Depending on this value, Lines may look too thin from afar
## or too thick from close up, so this must be tweaked according to the
## intended usage.
@export var width_factor := 0.01

## How many instances to add to the [MultiMeshInstance] when the pool is full.
## [br][br]
## [b]NOTE:[/b] this stopped working somwhere between Godot 4.2 and 4.4, as
## changing the [param MultiMeshInstance.instance_count] now also clears the internal
## mesh buffers, so this feature can't be used.
#@export var instance_increment := 64

## The initial amount of instances in the [MultiMeshInstance3D]
## [br][br]
## [b]NOTE:[/b]: since the latest Godot 4.x, this tool can no longer grow
## the instance counts dynamically, as changing the
## [param instance_count] on the [b]MultiMeshInstance[/b] now clears its internal mesh buffers.
## So for now, you need to set a high-enough [param instance_amount] and rely
## solely only on that.
@export var instance_amount := 64


@export_subgroup("Materials")

## The shading mode. If true, the materials will be fullbright.
@export var unshaded       := true
## If true, the materials will cast no shadows.
@export var no_shadows     := true # for materials  (TODO: there should be only one option for this)

## If true, lines/faces will be seen through the world geometry.
@export var on_top         := false  # no depth test

## Whether transparency is active or not.
@export var transparent    := false

## If true, faces will be double sided. This doesn't affect lines.
@export var double_sided   := false  # for the faces


@export_subgroup("Geometry")
## The amount of radial segments used to create filled spheres.
@export var sphere_radial_segments        := 24
## The amount of rings used to create filled spheres.
@export var sphere_rings                  := 12
## The amount of rings used to create hollow spheres.
@export var hollow_sphere_radial_segments := 8
## The amount of rings used to create hollow spheres.
@export var hollow_sphere_rings           := 6
## The amount of segments used to create circles.
@export var circle_segments               := 32

## The amount of segments used to create the cylinders that make up the lines.
var cylinder_radial_segments      := 5

@export_subgroup("Colors")
## The default color used to make lines. [br][br]Can be overriden in the drawing
## functions, unless [param use_single_color] is true.
@export var line_color     := Color.WHITE

## The default color used to make faces.
@export var face_color     := Color.WHITE

## The default color used to make the backlines. (The lines that are seen
## through world geometry when [param see_through_geometry] is true.)
## [br][br]Can be overriden in the drawing functions, unless [param use_single_color] is true.
@export var backline_color := Color.BLACK

## The default color used to make the backfaces. (The faces that are seen
## through world geometry when [param see_through_geometry] is true.)
@export var backface_color := Color.BLACK


#@export var back_alpha := 0.1
#@export var face_alpha := 0.5
#@export var darken_factor := 0.5



#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

#    initialization

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#region initialization
enum {A,B,C,D,E,F,G,H}

const _DOT_THRESHOLD := 0.999
const _USE_CYLINDERS_FOR_LINES := false  # keep this false, the cylinders code is not working in Godot 4

var _multi_meshes      : Dictionary                # MultiMeshes
var _im_faces          : ImmediateMesh
var _im_fallback_lines : ImmediateMesh  # to fill the spaces when thick lines aren't visible due to distance
var _labels            : Array[Label3D]
var _labels_root       : Node3D

var _num_labels         := 0
var _num_visible_labels := 0

var _back_mat          : StandardMaterial3D
var _fore_mat          : StandardMaterial3D
var _im_faces_back_mat : StandardMaterial3D
var _im_faces_fore_mat : StandardMaterial3D


func _ready() -> void:
	name = "DrawTool3D"

	_labels_root = Node3D.new()
	add_child(_labels_root)
	_labels_root.name = "3d_labels"

	_init_im()
	_init_mmis()

	_im_fallback_lines = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.name = "Fallback_Lines_MeshInstance3D"
	mi.mesh = _im_fallback_lines
	mi.material_override = _back_mat
	add_child(mi)


func _init_im() -> void:
	if not see_through_geometry:
		_im_faces_back_mat = _create_material(line_color)
		_im_faces_back_mat.cull_mode = BaseMaterial3D.CULL_DISABLED if double_sided else BaseMaterial3D.CULL_BACK
	else:
		_im_faces_fore_mat = _create_material(face_color)
		_im_faces_fore_mat.cull_mode = BaseMaterial3D.CULL_DISABLED if double_sided else BaseMaterial3D.CULL_BACK
		_im_faces_fore_mat.render_priority = render_priority
		_im_faces_fore_mat.no_depth_test = false

		_im_faces_back_mat = _create_material(backface_color)
		_im_faces_back_mat.cull_mode = BaseMaterial3D.CULL_DISABLED if double_sided else BaseMaterial3D.CULL_BACK
		_im_faces_back_mat.render_priority = render_priority-1
		#_im_faces_back_mat.next_pass = _im_faces_fore_mat
		_im_faces_back_mat.no_depth_test = true

	_im_faces = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.name = "Faces_MeshInstance3D"
	mi.mesh = _im_faces
	mi.material_override = _im_faces_back_mat
	add_child(mi)


func _init_mmis() -> void:
	if not see_through_geometry:
		_back_mat = _create_material(Color.WHITE if not single_color else line_color)
	else:
		_fore_mat = _create_material(line_color)
		_fore_mat.render_priority = render_priority
		_fore_mat.no_depth_test = false
		# for some reason, this only works if this material is transparent
		_fore_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		_back_mat = _create_material(backline_color)
		_back_mat.render_priority = render_priority-1
		_back_mat.next_pass = _fore_mat
		_back_mat.no_depth_test = true

	# if use_only_thin_lines: return

	if _USE_CYLINDERS_FOR_LINES:
		_multi_meshes["cylinder_lines"] = _init_line_mesh__cylinder(_back_mat)
	else:
		_multi_meshes["cube_lines"] = _init_line_mesh__cube(_back_mat)

	_multi_meshes["cones"]   = _init_cone_mesh(_back_mat)
	_multi_meshes["cubes"]   = _init_cube_mesh(_back_mat)
	_multi_meshes["spheres"] = _init_sphere_mesh(_back_mat)

	# TODO: textmeshes will require some work to support outlines
#	_multi_meshes["texts"]   = _init_text_mesh(_back_mat)


func _create_material(color:Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = not single_color
	mat.no_depth_test = on_top
	mat.disable_receive_shadows = no_shadows

	if unshaded: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:        mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	if transparent: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:           mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	return mat


# this is the one used for lines as cylinders
func _init_line_mesh__cylinder(mat:StandardMaterial3D) -> MultiMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = width_factor
	cylinder.bottom_radius = width_factor
	cylinder.height = 1
	cylinder.radial_segments = cylinder_radial_segments
	cylinder.rings = 0
	cylinder.cap_top = false
	cylinder.cap_bottom = false

	cylinder.material = mat
	return _create_multimesh(cylinder, "Cylinders_MultiMeshInstance3D")


# this is the one used for lines as cubes
func _init_line_mesh__cube(mat:StandardMaterial3D) -> MultiMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3(width_factor, width_factor, 1)

	cube.material = mat
	return _create_multimesh(cube, "CubeLines_MultiMeshInstance3D")


func _init_cube_mesh(mat:StandardMaterial3D) -> MultiMesh:
	var box_mesh := BoxMesh.new()
	box_mesh.material = mat
	return _create_multimesh(box_mesh, "Cubes_MultiMeshInstance3D")


#func _init_text_mesh(mat:StandardMaterial3D) -> MultiMesh:
#	var text_mesh := TextMesh.new()
#	text_mesh.material = mat
#
#	return _create_multimesh(text_mesh)


func _init_cone_mesh(mat:StandardMaterial3D) -> MultiMesh:
	# ----------------------------------------
	# create cones (for vectors)
	var cone := CylinderMesh.new()
	cone.top_radius = 0
	cone.bottom_radius = width_factor
	cone.height = width_factor*4
	cone.radial_segments = sphere_radial_segments
	cone.rings = 0
	cone.material = mat

	return _create_multimesh(cone, "Cones_MultiMeshInstance3D")


func _init_sphere_mesh(mat:StandardMaterial3D) -> MultiMesh:
	# ----------------------------------------
	# create spheres
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1
	sphere.radial_segments = sphere_radial_segments
	sphere.rings = sphere_rings
	sphere.material = mat

	return _create_multimesh(sphere, "Spheres_MultiMeshInstance3D")


@warning_ignore("shadowed_variable_base_class")
func _create_multimesh(mesh:Mesh, name:String) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
#	mm.color_format = MultiMesh.COLOR_FLOAT
	mm.use_colors = true
	mm.mesh = mesh
	mm.visible_instance_count = 0
	mm.instance_count = instance_amount

	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm

	var cast_shadows := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if no_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# for some reason only the setter function seems to work (last I checked)
	#mmi.set("cast_shadows", cast_shadows as GeometryInstance3D.ShadowCastingSetting)
	#mmi.cast_shadows = cast_shadows
	mmi.set_cast_shadows_setting(cast_shadows)

	add_child(mmi)
	return mm

#endregion initialization


#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

#    Internal API

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#region Internal API
@warning_ignore("shadowed_variable_base_class")
func _create_circle_points(position:Vector3, axis:Vector3, num_segments:int, start_angle:=0) -> Array:
	var radius := axis.length()
	axis = axis.normalized()
	assert(axis != Vector3.ZERO)

	# TODO: when the axis used in the cross product below is the same
	# as the circle's axis, use a perpendicular axis instead
	var _cross_axis := Vector3.UP
	if axis == _cross_axis:
		_cross_axis = Vector3.RIGHT
		#if _cross_axis == Vector3.RIGHT:
			#_cross_axis = Vector3.UP
		#elif _cross_axis == Vector3.UP:
			#_cross_axis = Vector3.RIGHT

	var points := []
	var cross := axis.cross(_cross_axis).normalized()

	# this was intended for some edge cases, but seems like the condition is never true
	var dot :float = abs(cross.dot(axis))
	if dot > 0.9:
		printerr(_create_circle_points, ": THIS CODE IS RUNNING!")
		cross = axis.cross(Vector3.UP) * radius

	# draw a debug cross-product vector
	#draw_line(position, position+cross, Color.PURPLE, 2)
	#cone(position+cross, cross, Color.PURPLE, 2)

	var dist := 360.0/float(num_segments)
	for i:int in num_segments+1:
		var r := deg_to_rad(start_angle+dist*i)
		var c := cross.rotated(axis, r)
		var p := position + c * radius
		points.append(p)

	#for r:int in range(start_angle, 360+start_angle, 360/float(num_segments)):
		#var c := cross.rotated(axis, deg_to_rad(r)).normalized()
		#var p := position + c * radius
		#points.append(p)
	#if connect:
		#points.append(points[0])
	return points


func _create_arc_points(pos:Vector3, axis:Vector3, arc_angle:float, num_segments:int, start_angle:=0) -> Array:
	var radius := axis.length()
	axis = axis.normalized()
	assert(axis != Vector3.ZERO)

	var _cross_axis := Vector3.UP
	if axis == _cross_axis:
		_cross_axis = Vector3.RIGHT

	var points := []
	var cross := axis.cross(_cross_axis).normalized()# *  radius

	# this was intended for some edge cases, but seems like the condition is never true
	var dot :float = abs(cross.dot(axis))
	if dot > 0.9:
		printerr(_create_arc_points, ": THIS CODE IS RUNNING!")
		cross = axis.cross(Vector3.UP) * radius


	# draw a debug cross-product vector
	#draw_line(pos, pos+cross, Color.PURPLE, 2)
	#cone(pos+cross, cross, Color.PURPLE, 2)
	#arc_angle += 4

	var dist := arc_angle/float(num_segments)
	for i:int in num_segments+1:
		var r := deg_to_rad(start_angle+dist*i)
		var c := cross.rotated(axis, r)
		var p := pos + c * radius
		points.append(p)

	#for r:int in range(start_angle, start_angle+arc_angle, arc_angle/float(num_segments)):
		#var c := cross.rotated(axis, deg_to_rad(r))
		#var p := pos + c * radius
		#points.append(p)
	#if connect:
		#points.append(points[0])
	return points


func _create_circle_points_OLD(pos:Vector3, radius:Vector3, axis:Vector3) -> Array:
	var points := []

	for r:int in range(0, 360, 360/float(sphere_radial_segments)):
		var p := pos + radius.rotated(axis, deg_to_rad(r))
		points.append(p)

	return points


# Reference used:  http://kidscancode.org/godot_recipes/3.x/3d/3d_align_surface/
@warning_ignore("shadowed_variable_base_class") # 'tr' is actually an Object method!! WTF...!?
func align_with_y(tr:Transform3D, new_y:Vector3) -> Transform3D:
	if new_y.dot(Vector3.FORWARD) in [-1, 1]:
#		new_y = Vector3.RIGHT
		tr.basis.y = new_y
		tr.basis.z = tr.basis.x.cross(new_y)
		tr.basis = tr.basis.orthonormalized()
	else:
		#printt("dot: ", new_y.dot(Vector3.FORWARD), new_y)

		tr.basis.y = new_y
		tr.basis.x = -tr.basis.z.cross(new_y)
		tr.basis = tr.basis.orthonormalized()
	return tr


#TODO: Test if it's really better to add many instances once in a while
#      versus adding one instance every time it's needed.
#      Maybe there's a tradeoff between too many and too few.
func _add_instance_to(mm:MultiMesh) -> int:
	# the index of a new instance is count-1
	var idx := mm.visible_instance_count

	# WARNING: this no longer works since Godot 4.3 or so, because, for some
	#          stupid reason, changing the instance count now clears the internal
	#          buffers of the MultiMeshInstance
	#          For now, set the initial instance count to be high enough
	#          that this never happens

	# if the visible count reaches the instance count, then more instances are needed
	if mm.instance_count <= mm.visible_instance_count+1:
		# this is enough to make the MultiMesh create more instances internally
		mm.instance_count *= 2

	mm.visible_instance_count += 1
	return idx


@warning_ignore("shadowed_variable_base_class")
func _commit_instance(mm:MultiMesh, idx:int, transform:Transform3D, color:Color) -> void:
	mm.set_instance_transform(idx, transform)
	# TODO: check what to do about this when using 'single_color'
	mm.set_instance_color(idx, color if not single_color else line_color)



func _add_line(a:Vector3, b:Vector3, color:Color, thickness:=line_thickness) -> void:
	if _USE_CYLINDERS_FOR_LINES:
		_add_line_cylinder(a, b, color, thickness)
	else:
		_add_line_cube(a, b, color, thickness)




func _points_are_equal(a:Vector3, b:Vector3) -> bool:
	if a != b: return false
#	push_warning("points 'a' and 'b' are the same: %s == %s" % [a, b])
	return true

func __add_back_line(a: Vector3, b: Vector3, color: Color) -> void:
	_im_fallback_lines.surface_begin(Mesh.PRIMITIVE_LINES)

	_im_fallback_lines.surface_set_color(color)
	_im_fallback_lines.surface_add_vertex(a)
	_im_fallback_lines.surface_set_color(color)
	_im_fallback_lines.surface_add_vertex(b)

	_im_fallback_lines.surface_end()


func _add_line_cube(a:Vector3, b:Vector3, color:Color, thickness:=1.0) -> void:
	if _points_are_equal(a, b): return

	__add_back_line(a, b, color)
	if use_only_thin_lines: return

	var mm:MultiMesh = _multi_meshes["cube_lines"]

	# adding an instance is basically just raising the visible_intance_count
	# and then using that index to get and set properties of the instance
	var idx := _add_instance_to(mm)

	# if transform is to be orthonormalized, do it here before applying any
	# scaling, or it will revert the scaling
	@warning_ignore("shadowed_variable_base_class")
	var transform := mm.get_instance_transform(idx).orthonormalized()
	transform.origin = (a+b)/2

	if not transform.origin.is_equal_approx(b):
		var up_vec := Vector3.UP
		if absf(a.direction_to(b).dot(Vector3.UP)) > _DOT_THRESHOLD:
			up_vec = Vector3.BACK
		transform = transform.looking_at(b, up_vec )

	# add this, so the lines go slightly over the points and corners look right
	var corner_fix:float = width_factor * thickness

	transform = transform.scaled_local(Vector3(
		thickness,
		thickness,
		a.distance_to(b) + corner_fix,
	))

	_commit_instance(mm, idx, transform, color)





func _add_line_cylinder(a:Vector3, b:Vector3, color:Color, thickness:=1.0) -> void:
	if _points_are_equal(a, b): return

	__add_back_line(a, b, color)
	if use_only_thin_lines: return

	var mm:MultiMesh = _multi_meshes["cylinder_lines"]
	var idx := _add_instance_to(mm)

	@warning_ignore("shadowed_variable_base_class")
	var transform := Transform3D() # mm.get_instance_transform(idx).orthonormalized()
	transform.origin = (a+b)/2

	if not transform.origin.is_equal_approx(b):
		var up_vec := Vector3.UP
		if absf(a.direction_to(b).dot(Vector3.UP)) > _DOT_THRESHOLD:
			up_vec = Vector3.BACK
		transform = transform.looking_at(b, up_vec )

	var corner_fix:float = width_factor * thickness
	transform = transform.rotated_local(Vector3.RIGHT, deg_to_rad(-90));
	transform = transform.scaled_local(Vector3(
		thickness,
		a.distance_to(b) + corner_fix,
		thickness
	));

	_commit_instance(mm, idx, transform, color)


@warning_ignore("shadowed_variable_base_class", "unused_parameter")
func _add_cone(position:Vector3, direction:Vector3, color:Color, thickness:=1.0) -> void:
	var mm:MultiMesh = _multi_meshes["cones"]

	var idx := _add_instance_to(mm)
	var tranf := Transform3D()
	tranf.origin = position

	var a := position
	var b := position+direction

	if not tranf.origin.is_equal_approx(b):
		var up_vec := Vector3.UP
		if absf(a.direction_to(b).dot(Vector3.UP)) > _DOT_THRESHOLD:
			up_vec = Vector3.BACK
		tranf = tranf.looking_at(b, up_vec)

	tranf = tranf.rotated_local(Vector3.RIGHT, deg_to_rad(-90));
	tranf = tranf.scaled_local(Vector3.ONE * thickness);

	_commit_instance(mm, idx, tranf, color)


@warning_ignore("shadowed_variable_base_class")
func _add_sphere_filled(pos:Vector3, color:Color, size:=1.0) -> void:
	var mm:MultiMesh = _multi_meshes["spheres"]

	var idx := _add_instance_to(mm)
#	var transform := mm.get_instance_transform(idx).orthonormalized()
	var tranf := Transform3D()

	tranf.origin = pos
	tranf.basis = tranf.basis.scaled(Vector3.ONE * size)

	_commit_instance(mm, idx, tranf, color)


func __add_back_line_poly(verts: PackedVector3Array, color: Color) -> void:
	_im_fallback_lines.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	for v: Vector3 in verts:
		_im_fallback_lines.surface_set_color(color)
		_im_fallback_lines.surface_add_vertex(v)

	_im_fallback_lines.surface_end()


func _add_sphere_hollow(pos:Vector3, color:Color, diameter:=1.0, thickness:=1.0) -> void:
	var radius := diameter/2.0
	#var meridian_points := _create_circle_points(pos, Vector3.RIGHT*radius, hollow_sphere_rings*2, 90)
	#meridian_points.resize(meridian_points.size()/2.0)   # only interested in half of the circle here

	var pts := _create_arc_points(pos, Vector3.UP*radius, 360, 16, 90)
	__add_back_line_poly(pts, color)
	draw_polyline(pts, color, thickness)
	#draw_circle(pos, Vector3.UP*radius, color, thickness, 16)

	var num_segments := 4
	var angle := 360.0/num_segments

	for i:int in num_segments/2.0:
		var direction := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(i * angle))
		var points := _create_arc_points(pos, direction*radius, 360, 16, 90)
		#draw_circle(pos, direction*radius, Color.GREEN, thickness)
		draw_polyline(points, color, thickness)


func _add_sphere_hollow2(pos:Vector3, color:Color, diameter:=1.0, thickness:=1.0) -> void:
	var radius := diameter/2.0
	var meridian_points := _create_circle_points(pos, Vector3.RIGHT*radius, hollow_sphere_rings*2, 90)
	meridian_points.resize(int(meridian_points.size()/2.0))   # only interested in half of the circle here

	var a:Vector3 = meridian_points[1] # don't use 0, as it is the same as 'pos' in x and z
	var start_direction := Vector3(pos.x, a.y, pos.z).direction_to(a)

	var p1 := pos - Vector3.UP*radius

	for i in range(1, meridian_points.size()):
		var mp:Vector3 = meridian_points[i]
		var r:float = absf(mp.z-p1.z)
		var p := Vector3(p1.x, mp.y, p1.z)
		var points := _create_arc_points(p, Vector3.UP*r, 360, hollow_sphere_radial_segments, 90)
		__add_back_line_poly(points, color)
		draw_polyline(points, color, thickness)

	for i in hollow_sphere_radial_segments:
		var angle := 360.0/hollow_sphere_radial_segments
		var direction := start_direction.rotated(Vector3.UP, deg_to_rad(i * angle) )
		var points := _create_arc_points(pos, direction*radius, 180, hollow_sphere_rings, 90)
		__add_back_line_poly(points, color)
		draw_polyline(points, color, thickness)



func _add_cube(pos:Vector3, size:float, color:Color) -> void:
	#var p1 := pos
	#var p2 := p1+size

	var a := Vector3(0, 1, 0) * size + pos  # a
	var b := Vector3(1, 1, 0) * size + pos  # b
	var c := Vector3(1, 0, 0) * size + pos  # c
	var d := Vector3(0, 0, 0) * size + pos  # d
	var e := Vector3(0, 1, 1) * size + pos  # e
	var f := Vector3(1, 1, 1) * size + pos  # f
	var g := Vector3(1, 0, 1) * size + pos  # g
	var h := Vector3(0, 0, 1) * size + pos  # h

	draw_quad([a,e,h,d], color)  # West
	draw_quad([f,b,c,g], color)  # East
	draw_quad([b,a,d,c], color)  # North
	draw_quad([e,f,g,h], color)  # South
	draw_quad([a,b,f,e], color)  # Top
	draw_quad([h,g,c,d], color)  # Bottom


func _add_fast_cube(pos:Vector3, size:Vector3, color:Color) -> void:
	var mm:MultiMesh = _multi_meshes["cubes"]
	var idx := _add_instance_to(mm)

	var tranf := Transform3D() # mm.get_instance_transform(idx).orthonormalized()
	tranf.origin = pos
	tranf.basis = tranf.basis.scaled(Vector3.ONE * size)

	_commit_instance(mm, idx, tranf, color)


func _create_new_label(fixed_size:=false) -> Label3D:
	var l := Label3D.new()
	_labels_root.add_child(l)
	_labels.append(l)
	_num_labels += 1

	l.fixed_size    = fixed_size
	l.shaded        = not unshaded
	l.double_sided  = double_sided
	l.no_depth_test = on_top
	l.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	return l


func _clear_labels() -> void:
	for l:Label3D in _labels:
		l.visible = false
	_num_visible_labels = 0

# using a similar system to the MultiMeshInstance
@warning_ignore("shadowed_variable_base_class")
func _add_label(position:Vector3, string:String, color:Color, size:=1.0, fixed_size:=false) -> void:
	var l:Label3D
	_num_visible_labels += 1

	if _num_labels < _num_visible_labels:
		l = _create_new_label(fixed_size)
	else:
		l = _labels[_num_visible_labels-1]
		l.visible = true

	l.position = position
	l.text     = string
	l.modulate = color
	l.scale    = Vector3.ONE * size


#endregion    Internal API




#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=

#    Public API

#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#region Public API
func clear() -> void:
	# keep the real 'instance_count' up, to serve as a pool
	for mm:MultiMesh in _multi_meshes.values():
		mm.visible_instance_count = 0
	_clear_labels()
	_im_faces.clear_surfaces()
	_im_fallback_lines.clear_surfaces()


func draw_line(a:Vector3, b:Vector3, color:Color=line_color, thickness:=line_thickness) -> void:
	_add_line(a, b, color, thickness)


func draw_lines(lines: PackedVector3Array, color: Color=line_color, thickness:= line_thickness) -> void:
	assert(lines.size() % 2 == 0) # vertices must be even number
	for i in range(0, lines.size(), 2):
		_add_line(lines[i], lines[i+1], color, thickness)


# points = contiguous Array[Vector3]
func draw_polyline(points:Array, color:=line_color, thickness:=line_thickness) -> void:
	for i in range(1, points.size(), 1):
		_add_line(points[i-1], points[i], color, thickness)


func draw_polyline_dashed(points:Array, colors: PackedColorArray, thickness:=line_thickness) -> void:
	assert(colors.size() == points.size())
	for i in range(1, points.size(), 1):
		_add_line(points[i-1], points[i], colors[i], thickness)


func draw_quad(verts:Array[Vector3], color:Color) -> void:
	_im_faces.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := verts[A]
	var b := verts[B]
	var c := verts[C]
	var d := verts[D]

	var tri_verts := [a,b,c,a,c,d]

	for v:Vector3 in tri_verts:
		_im_faces.surface_set_color(color)
		_im_faces.surface_add_vertex(v)

	_im_faces.surface_end()


#func cube(p1:Vector3, p2:Vector3, flags:=ALL) -> void:
	#if flags & WIRE:  cube_lines(p1, p2, line_color, line_thickness)
	#if flags & FACES: draw_cube_faces(p1, p2, line_color)


func draw_cube_faces(pos:Vector3, size:float, color:Color) -> void:
#	var pos := Vector3(min(p1.x, p2.x), min(p1.y, p2.y), min(p1.z, p2.z))
	#var pos := (p1 + p2) / 2
	#var size := (p2-p1).abs()
	_add_cube(pos, size, color)


func draw_point_cube_faces(pos:Vector3, size:float, color:Color) -> void:
	_add_cube(pos, size, color)


func draw_fast_cube_faces(p1:Vector3, p2:Vector3, color:Color) -> void:
#	var pos := Vector3(min(p1.x, p2.x), min(p1.y, p2.y), min(p1.z, p2.z))
	var pos := (p1 + p2) / 2
	var size := (p2-p1).abs()
	_add_fast_cube(pos, size, color)


func draw_fast_point_cube_faces(p:Vector3, size:float, color:Color) -> void:
	_add_fast_cube(p, Vector3(size, size, size), color)


func cube_lines(p1:Vector3, p2:Vector3, color:Color, thickness:=line_thickness, draw_faces:=false, _face_color:Variant=null) -> void:
	var size := (p2-p1).abs()

	var a := Vector3(0, 1, 0) * size + p1  # a
	var b := Vector3(1, 1, 0) * size + p1  # b
	var c := Vector3(1, 0, 0) * size + p1  # c
	var d := Vector3(0, 0, 0) * size + p1  # d
	var e := Vector3(0, 1, 1) * size + p1  # e
	var f := Vector3(1, 1, 1) * size + p1  # f
	var g := Vector3(1, 0, 1) * size + p1  # g
	var h := Vector3(0, 0, 1) * size + p1  # h

	var pl1 := [a,b,c,d,a]
	var pl2 := [e,f,g,h,e]

	draw_polyline(pl1, color, thickness)
	draw_polyline(pl2, color, thickness)
	_add_line(a, e, color, thickness)
	_add_line(b, f, color, thickness)
	_add_line(c, g, color, thickness)
	_add_line(d, h, color, thickness)

	if draw_faces:
		if not _face_color:
			#_face_color = color
			pass
#
		#draw_cube_faces(p1, size, _face_color)
		pass


func draw_aabb(_aabb:AABB, color:Color, thickness:=line_thickness, draw_faces:=false) -> void:
	var p1 := _aabb.position
	var p2 := p1+_aabb.size
	var size := (p2-p1).abs().x

	var a := Vector3(0, 1, 0) * size + p1  # a
	var b := Vector3(1, 1, 0) * size + p1  # b
	var c := Vector3(1, 0, 0) * size + p1  # c
	var d := Vector3(0, 0, 0) * size + p1  # d
	var e := Vector3(0, 1, 1) * size + p1  # e
	var f := Vector3(1, 1, 1) * size + p1  # f
	var g := Vector3(1, 0, 1) * size + p1  # g
	var h := Vector3(0, 0, 1) * size + p1  # h

	var pl1 := [a,b,c,d,a]
	var pl2 := [e,f,g,h,e]

	draw_polyline(pl1, color, thickness)
	draw_polyline(pl2, color, thickness)
	_add_line(a, e, color, thickness)
	_add_line(b, f, color, thickness)
	_add_line(c, g, color, thickness)
	_add_line(d, h, color, thickness)

	if draw_faces:
		draw_cube_faces(p1, size, color)


# vertices should match the ordering specified in the reference
# at the top of this file
func draw_rectangle_verts(vertices: PackedVector3Array, color:Color, thickness:=line_thickness, _draw_faces:=false, _face_color:Variant=null) -> void:
	var a := vertices[A]
	var b := vertices[B]
	var c := vertices[C]
	var d := vertices[D]
	var e := vertices[E]
	var f := vertices[F]
	var g := vertices[G]
	var h := vertices[H]

	var pl1 := [a,b,c,d,a]
	var pl2 := [e,f,g,h,e]

	draw_polyline(pl1, color, thickness)
	draw_polyline(pl2, color, thickness)
	_add_line(a, e, color, thickness)
	_add_line(b, f, color, thickness)
	_add_line(c, g, color, thickness)
	_add_line(d, h, color, thickness)


func draw_rectangle(p1: Vector3, p2: Vector3, color:Color, thickness:=line_thickness, _draw_faces:=false, _face_color:Variant=null) -> void:
	var size := (p2-p1).abs()

	var a := Vector3(0, 1, 0) * size + p1  # a
	var b := Vector3(1, 1, 0) * size + p1  # b
	var c := Vector3(1, 0, 0) * size + p1  # c
	var d := Vector3(0, 0, 0) * size + p1  # d
	var e := Vector3(0, 1, 1) * size + p1  # e
	var f := Vector3(1, 1, 1) * size + p1  # f
	var g := Vector3(1, 0, 1) * size + p1  # g
	var h := Vector3(0, 0, 1) * size + p1  # h

	var pl1 := [a,b,c,d,a]
	var pl2 := [e,f,g,h,e]

	draw_polyline(pl1, color, thickness)
	draw_polyline(pl2, color, thickness)
	_add_line(a, e, color, thickness)
	_add_line(b, f, color, thickness)
	_add_line(c, g, color, thickness)
	_add_line(d, h, color, thickness)


# useful for drawing vectors as arrows, for example
@warning_ignore("shadowed_variable_base_class")
func draw_cone(position:Vector3, direction:Vector3, color:Color, thickness:=1.0) -> void:
	_add_cone(position, direction, color, thickness)


@warning_ignore("shadowed_variable_base_class")
func draw_sphere(position:Vector3, color:Color, size:=1.0, filled:=true, thickness:=1.0) -> void:
	if filled: _add_sphere_filled(position, color, size)
	else:      _add_sphere_hollow(position, color, size, thickness)


@warning_ignore("shadowed_variable_base_class")
func draw_circle(position:Vector3, normal:Vector3, color:Color, thickness:=1.0, num_segments:=circle_segments) -> void:
	var points := _create_circle_points(position, normal, num_segments)
	draw_polyline(points, color, thickness)


@warning_ignore("shadowed_variable_base_class")
func draw_text(position:Vector3, string:String, color:Color, size:=1.0) -> void:
	_add_label(position, string, color, size)



#endregion Public API
