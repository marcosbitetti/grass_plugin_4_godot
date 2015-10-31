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

# to execute ./godot.x11.tools.64 -e -path ../../../godot/grass_editor_2

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

	# point is inside this view]?
	func has_point(v):
		var r = Rect2( control.get_global_pos(), control.get_size() )
		return r.has_point(v)

	func _init(ct,vp):
		self.viewport = vp
		self.control = ct


func get_path_dir():
	var path
	# X11 and OSX
	if OS.has_environment('HOME'):
		path = OS.get_environment('HOME').plus_file('.godot')
	# Windows
	elif OS.has_environment('APPDATA'):
		path = OS.get_environment('APPDATA').plus_file('Godot')
	else:
		path = './'
	
	return path.plus_file('plugins/grass_editor/resources')

var camera_data = []
var template_code = []

####
# Find cameras from Viewports and store it in a array with custo dara
#
func find_cameras(node,lvl):
	if node.get_name().find('@SpatialEditorViewport') > -1:
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

	
	print("Grass Editor Plugin - loaded")
	

func _exit_tree():
	edit(null)
	grass_editor.hide()
	grass_editor.get_parent().remove_child(grass_editor)
	#grass_editor.queue_free()
	grass_editor = null
	
