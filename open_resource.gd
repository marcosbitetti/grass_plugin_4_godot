#########################################################################
# open_resource.gd                                                      #
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

extends FileDialog

const MODE_MESH = "Mesh"
const MODE_MATERIAL = "Material"

var preview_window = WindowDialog.new()
var vp = Viewport.new()
var light = OmniLight.new()
var cam = Camera.new()
var pivo = Spatial.new()
var mesh_i = MeshInstance.new()
var rot = 0
var mode = MODE_MESH
var tree
var path_line
var old_line = "res://"
var callback
var callback_obj
var sphere


func make_sphere():
	var segments = 20
	var radius = 0.4
	var dist = (2*radius)/segments
	var st = SurfaceTool.new()
	var angle = PI / segments
	
	# TODO

# call the registed handle function from caller
func select_file_act(path):
	if callback_obj:
		if callback:
			callback_obj.call(callback,path)

# update the preview window
func object_selected_act(path):
	if path.find('.msh')<0 and path.find('.mat')<0:
		return
	path = path_line.get_text() + '/' + path
	if mode == MODE_MESH:
		var res = ResourceLoader.load(path, mode)
		if res:
			show_preview(res)
	#else:
	#	if sphere==null:
	#		sphere = make_sphere()
	#	show_preview(sphere)
	

# adjust preview window and posicione elements
func show_preview(mesh):
	preview_window.set_pos(Vector2(get_margin(MARGIN_LEFT)+get_size().x,get_margin(MARGIN_TOP)))
	preview_window.set_size(Vector2(200, get_size().y))
	preview_window.show()
	
	mesh_i.set_mesh(mesh)
	var aabb = mesh_i.get_aabb()
	var dist = 2*max(aabb.size.x,aabb.size.z)
	light.set_parameter(Light.PARAM_RADIUS, dist*2)
	light.set_translation(Vector3(aabb.size.x, aabb.size.y, dist))
	cam.set_translation(Vector3(0,aabb.size.y*1.4,dist*0.7))
	cam.look_at(Vector3(0,aabb.end.y-aabb.size.y*0.4,0), Vector3(0,1,0))

# destroy all content
func hide_elements():
	set_process(false)
	preview_window.hide()
	preview_window.queue_free()
	queue_free()


func _process(delta):
	# rotate model
	rot += 0.3*delta
	mesh_i.set_rotation(Vector3(0,rot,0))
	
	# gross method to verify for changes in tree structure
	var tx = tree.get_selected().get_text(0)
	if tx != old_line:
		old_line = tx
		object_selected_act(tx)

# find a node by type
func _find(node,tp):
	if node.is_type(tp):
		return node
	for nd in node.get_children():
		var t = _find(nd,tp)
		if t:
			return t
	return false

func _ready():
	# preview
	cam.set_translation(Vector3(0,0,2))
	vp.add_child(cam)
	light.set_translation(Vector3(2,0,2))
	pivo.add_child(mesh_i)
	vp.add_child(light)
	vp.add_child(pivo)
	vp.set_use_own_world(true)
	preview_window.add_child(vp)
	preview_window.set_title(tr('Preview'))
	
	preview_window.set_owner(self)
	add_child(preview_window)
	
	tree = _find(self,'Tree')
	path_line = _find(self,'LineEdit')
	
	set_process(true)
	

func _init(callback_obj,callback=null, md = MODE_MESH):
	set_mode(MODE_OPEN_FILE)
	set_access(ACCESS_RESOURCES)
	mode = md
	if md == MODE_MESH:
		add_filter('*.msh;Godot Mesh')
		add_filter('*.msh;Godot Mesh')
		add_filter('*.res;Godot Mesh Resource')
		add_filter('*.xml;Godot Mesh XML')
		add_filter('*.xmsh;Godot Mesh XML')
	else:
		add_filter('*.mtl;Godot Material')
		add_filter('*.res;Godot Material Resource')
		add_filter('*.xml;Godot Material XML')
		add_filter('*.xmtl;Godot Material XML')
	
	connect("file_selected",self,"select_file_act")
	connect("popup_hide",self,"hide_elements")
	
	self.callback_obj = callback_obj
	self.callback = callback


