#########################################################################
# GrassPlugin.gd                                                        #
#########################################################################
#                        This file is part of:                          #
#                         WILD WITCH PROJECT                            #
#                     http://www.wildwitchproject/                      #
#########################################################################
#                             CC-BY-SA                                  #
#   Wild Witch Project by Marcos Augusto Bitetti is licensed under a    #
#   Creative Commons Attribution-ShareAlike 4.0 International License.  #
#   Based on a work at http://www.wildwitchproject.com/.                #
#   Permissions beyond the scope of this license may be available at    #
#   http://www.wildwitchproject.com/p/direitos-da-obra.html.            #
#########################################################################

tool
extends EditorPlugin

# to execute in dev machine ./godot.x11.tools.64 -e -path ../../../godot/grass_editor_2

const GrassEditorControl = preload("GrassEditorControl.gd")
const default_plant1 = preload('resources/plant1.tex')
const default_plant1n = preload('resources/plant1n.tex')
const icon = preload('ico.png')
var default_mesh

var grass_editor

###
# A functon to prepare a default mesh, based on singleton patterns
###
func make_default_mesh():
	# return  the mesh if already made
	if default_mesh != null:
		return default_mesh

	var mt = FixedMaterial.new()
	mt.set_texture(FixedMaterial.PARAM_DIFFUSE, default_plant1)
	mt.set_texture(FixedMaterial.PARAM_NORMAL, default_plant1n)
	mt.set_fixed_flag( FixedMaterial.FLAG_USE_ALPHA, true )
	mt.set_fixed_flag( FixedMaterial.FLAG_DOUBLE_SIDED, true )
	mt.set_blend_mode(Material.BLEND_MODE_PREMULT_ALPHA )
	mt.set_depth_draw_mode(Material.DEPTH_DRAW_OPAQUE_PRE_PASS_ALPHA)
	
	var up = Vector3(0, 1, 0)
	var nor = Vector3(1,0,0)
	var a = -0.5	#x
	var b = 0.5		#x
	var c = -0.15	#y
	var d = 0.75	#y
	var m = SurfaceTool.new()
	m.set_material(mt)
	m.begin(4)
	
	var ang = 0
	for i in range(5):
		m.add_uv(Vector2(0, 0))
		m.add_vertex(Vector3(a, d, 0).rotated(up,ang))
		#m.add_normal(nor.rotated(up,ang))
		
		m.add_uv(Vector2(1, 0))
		m.add_vertex(Vector3(b, d, 0).rotated(up,ang))
		#m.add_normal(nor.rotated(up,ang))
		
		m.add_uv(Vector2(0, 1))
		m.add_vertex(Vector3(a, c, 0).rotated(up,ang))
		#m.add_normal(nor.rotated(up,ang))
		
		m.add_uv(Vector2(1, 1))
		m.add_vertex(Vector3(b, c, 0).rotated(up,ang))
		#m.add_normal(nor.rotated(up,ang))
		
		m.add_uv(Vector2(0, 1))
		m.add_vertex(Vector3(a, c, 0).rotated(up,ang))
		#m.add_normal(nor.rotated(up,ang))
		
		m.add_uv(Vector2(1, 0))
		m.add_vertex(Vector3(b, d, 0).rotated(up,ang))
		#m.add_normal(nor.rotated(up,ang))
		
		ang += PI/2.5
	
	m.generate_normals()
	m.index()

	default_mesh = m.commit()
	return default_mesh


####
# Pencil to draw
#
class Pencil extends Control:
	
	var mouse = Vector2()
	var _size = 1
	var _pos
	var _cam
	var _offset_control = null
	
	func show_pencil(pos, camera, transform,size):
		mouse = camera.unproject_position(pos)
		_size = mouse.distance_to( camera.unproject_position(pos+Vector3(size,0,0) ) )
		_cam = camera
		_pos = pos
		update()
	
	func _draw():
		if not _offset_control:
			return
		draw_set_transform(mouse + _offset_control.get_global_pos(), 0, Vector2(1,1))
		draw_circle(Vector2(0,0), _size, Color(1,1,1,0.05))
	
	func _init():
		pass


######
# CameraData is a data container to store Editor UI data
# Cameras are mounted in Editor with this structure:
#		@Control{...}:
#			@SpatialEditorViewport{...}:
#				@Control{...}:
#					@Viewport{...}:
#						@Camera{...}:
#
class CameraData:
	var control
	var viewport
	var shape = Pencil.new()

	# point is inside this view]?
	func has_point(v):
		var r = Rect2( control.get_global_pos(), control.get_size() )
		return r.has_point(v)

	func _init(ct,vp):
		self.viewport = vp
		self.control = ct
		self.shape.set_as_toplevel(true)
		self.shape.set_process_unhandled_input(false)
		self.shape.set_ignore_mouse(true)
		self.shape._offset_control = ct
		ct.add_child(self.shape)


func get_path_dir():
	var path
	# X11 and OSX
	#if OS.has_environment('HOME'):
	#	path = OS.get_environment('HOME').plus_file('.godot')
	# Windows
	#elif OS.has_environment('APPDATA'):
	#	path = OS.get_environment('APPDATA').plus_file('Godot')
	#else:
	#	path = './'

	path = icon.get_path()
	path = path.substr(0,path.find('ico.png')-1)
	
	return "".plus_file( path + '/resources')
	#return path.plus_file('plugins/grass_editor/resources')

var camera_data = []
var template_code = []

####
# Find cameras from Viewports and store it in a array with custo dara
# The form of Editor's envoronment appears like it:
#		root:
#			EditorNode:
#				@EditorFileSystem2:
#				@EditorImportExport3:
#				@Panel4:
#					@VBoxContainer8:
#						@HSplitContainer13:
#							@HSplitContainer17:
#								@HSplitContainer21:
#									@VSplitContainer22:
#										@VSplitContainer38:
#											@VBoxContainer39:
#												@Panel44:
#													@Control46:
#														@SpatialEditor7529:
#															@HSplitContainer7387:
#																@VSplitContainer7388:
#																	@Control7389:
#																		@SpatialEditorViewport7398:
#																			@Control7390:
#																				@Viewport7391:
#																					@Camera7393:
# then our code find this structure from viewport
func find_cameras(node,lvl):
	# after revision 9251298f46537cde669e66ed740c9987678c4617 from 12/2015 somethings changed, the second condition
	# from this IF solve this problem.
	if node.get_name().find('@SpatialEditorViewport') > -1 or node.get_type().find('SpatialEditorViewport') > -1:
		#print('camera !')
		#printt('position',node.get_child(0).get_global_pos())
		#printt('size    ',node.get_child(0).get_size())
		#printt('cam     ',node.get_child(0).get_child(0).get_camera())
		camera_data.push_back( CameraData.new( node.get_child(0), node.get_child(0).get_child(0) ) )
	lvl += 1
	if lvl>20:
		return
	for nd in node.get_children():
		find_cameras(nd,lvl)


####
# helper function
#
func _tree_to_string(node,lvl):
	var ident = ''
	for i in range(lvl):
		ident += "\t"
	var s = ident + node.get_name() + ':' + node.get_type() + "\n"
	for child in node.get_children():
		s += _tree_to_string(child,lvl+1)

	return s



static func get_name():
	return "Grass Editor"

func edit(object):
	print(object)

func handles(object):
	return object.get_type() == 'Spatial'

func make_visible(visible):
	pass

func _enter_tree():
	# load template
	if template_code.size()==0:
		var path = get_path_dir()
		print('TEMP ', path)
		var tmp_file = File.new()
		tmp_file.open(path.plus_file('grass_foliage_generator.gd.template'), File.READ)
		while not tmp_file.eof_reached():
			template_code.push_back(tmp_file.get_line())
		tmp_file.close()

	find_cameras(get_node("/root/EditorNode"),0)
	var base = get_node("/root/EditorNode").get_gui_base()
	grass_editor = GrassEditorControl.new( camera_data, make_default_mesh(), template_code, icon)
	grass_editor.undo_redo = get_undo_redo()
	add_custom_control(CONTAINER_SPATIAL_EDITOR_SIDE, grass_editor)

	# Do not disomment it if you no need study the editor.
	# This is a routine to examinate the Editor's structure
	# to help in future editor changes
	#var content = _tree_to_string(get_node("/root/EditorNode"),0)
	#var file = File.new()
	#file.open('user://editor.struct.txt',File.WRITE)
	#file.store_string(content)
	#file.close()

	
	print("Grass Editor Plugin - loaded")
	

func _exit_tree():
	edit(null)
	grass_editor.hide()
	grass_editor.get_parent().remove_child(grass_editor)
	#grass_editor.queue_free()
	grass_editor = null
	
	#pencils
	for c in camera_data:
		c.shape.queue_free()
