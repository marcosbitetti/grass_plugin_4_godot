#########################################################################
# GrassEditorControll.gd                                                #
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
extends VBoxContainer

# main variables
var _is_mouse_pressed = false
var _pencil = false
var mouse_pos = Vector2()
var camera_data = []
var selected_viewport
var viewport_offset = Vector2()
var selected_editor_control
var default_mesh
var selected_grass_mesh
var undo_redo
var template_code = []
var icon

###
# Control for each layer in panel
class GrassLayerData extends VBoxContainer:
	
	var material
	var mesha
	var ref
	
	var mesh_bt
	var mat_bt
	
	func load_mesh_dialog():
		var dialog = FileDialog.new()
		if get_tree().get_current_scene()==null:
			get_node("/root/EditorNode").get_gui_base().add_child(dialog)
		else:
			get_tree().get_current_scene().add_child(dialog)
		
		dialog.set_size(Vector2(500,400))
		dialog.add_filter('*.msh;Godot Mesh')
		dialog.add_filter('*.res;Godot Mesh Resource')
		dialog.add_filter('*.xml;Godot Mesh XML')
		dialog.add_filter('*.xmsh;Godot Mesh XML')
		dialog.set_mode(FileDialog.MODE_OPEN_FILE)
		dialog.set_access(FileDialog.ACCESS_RESOURCES)
		dialog.connect("file_selected",self,'load_mesh_done')
		
		dialog.popup_centered()
	
	func load_material_dialog():
		var dialog = FileDialog.new()
		if get_tree().get_current_scene()==null:
			get_node("/root/EditorNode").get_gui_base().add_child(dialog)
		else:
			get_tree().get_current_scene().add_child(dialog)
		
		dialog.set_size(Vector2(500,400))
		dialog.add_filter('*.mtl;Godot Material')
		dialog.add_filter('*.res;Godot Material Resource')
		dialog.add_filter('*.xml;Godot Material XML')
		dialog.add_filter('*.xmtl;Godot Material XML')
		dialog.set_mode(FileDialog.MODE_OPEN_FILE)
		dialog.set_access(FileDialog.ACCESS_RESOURCES)
		dialog.connect("file_selected",self,'load_material_done')
		
		dialog.popup_centered()
	
	func load_mesh_done(evt):
		var msh = ResourceLoader.load(evt)
		self.ref.get_multimesh().set_mesh(msh)
		var p = evt.rfind('/')+1
		mesh_bt.set_text(evt.substr(p,evt.length()-p))
	
	func load_material_done(evt):
		var mtl = ResourceLoader.load(evt)
		self.ref.set_material_override(mtl)
		var p = evt.rfind('/')+1
		mat_bt.set_text(evt.substr(p,evt.length()-p))
	
	func active_this_layer():
		self.ref.get_parent().layer_index = self.get_index()
		self.ref.get_parent().get_layers_handlers()
	
	func remove_layer():
		var parent = self.ref.get_parent()
		if parent.get_child_count()==1:
			return
		parent.layer_index = 0
		parent.remove_child(self.ref)
		parent.get_layers_handlers()
		self.queue_free()
	
	func _ready():
		set_h_size_flags(SIZE_EXPAND_FILL)
		
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		var bt = Button.new()
		var chk = CheckBox.new()
		
		chk.connect("pressed",self,"active_this_layer")
		chk.set_h_size_flags(SIZE_EXPAND_FILL)
		chk.set_tooltip(tr('Set active layer'))
		chk.set_text( tr('Layer ') + str( self.get_index() ) )
		if self.ref.get_parent().layer_index == self.get_index():
			chk.set_pressed(true)
		hbox.add_child(chk)
		bt.set_text('X')
		bt.set_tooltip(tr('Remove Layer'))
		bt.connect("pressed",self,'remove_layer')
		hbox.add_child(bt)
		add_child(hbox)
		
		hbox = HBoxContainer.new()
		
		var mesh_name = self.ref.get_multimesh().get_mesh().get_path()
		mesh_name = mesh_name.substr(mesh_name.rfind('/')+1,mesh_name.length())
		
		var mat_name = ''
		if self.ref.get_material_override()!=null:
			mat_name = self.ref.get_material_override().get_path()
			mat_name = mat_name.substr(mat_name.rfind('/')+1,mat_name.length())
		
		lbl = Label.new()
		bt = Button.new()
		#bt.set_text(tr('default'))
		bt.set_text( mesh_name )
		bt.set_h_size_flags(SIZE_EXPAND_FILL)
		bt.connect("pressed",self,'load_mesh_dialog')
		lbl.set_text(tr('mesh: '))
		hbox.set_h_size_flags(SIZE_EXPAND_FILL)
		hbox.add_child(lbl)
		hbox.add_child(bt)
		add_child(hbox)
		mesh_bt = bt
		
		hbox = HBoxContainer.new()
		lbl = Label.new()
		bt = Button.new()
		#bt.set_text(tr('default'))
		bt.set_text(mat_name)
		bt.set_h_size_flags(SIZE_EXPAND_FILL)
		bt.connect("pressed",self,'load_material_dialog')
		lbl.set_text(tr('material: '))
		hbox.set_h_size_flags(SIZE_EXPAND_FILL)
		hbox.add_child(lbl)
		hbox.add_child(bt)
		add_child(hbox)
		mat_bt = bt
		
		add_child( HSeparator.new() )
	
	func _init(link):
		self.ref = link

###
# Manage a grass node
class GrassNode extends Spatial:
	
	var grass_list = []
	var matrix = []
	var dist = Vector2(0.5,0.5)
	var divisions = Vector2()
	var height = 1
	var begin = Vector3()
	var layer_index = 0
	var layer_panel
	# strange soluction to contour capsole of class
	#var _layer_data_class
	
	func add_layer(static_mesh):
		var instance = MultiMeshInstance.new()
		var mesh = MultiMesh.new()
		var aabb = get_parent().get_aabb()
		instance.set_draw_range_begin( get_parent().get_draw_range_begin() )
		instance.set_draw_range_end( get_parent().get_draw_range_end() )
		instance.set_multimesh(mesh)
		mesh.set_aabb(aabb)
		mesh.set_mesh(static_mesh)
		add_child(instance)
		setup_layer(mesh)
		
		var g = GrassLayerData.new(instance)
		layer_panel.add_child(g)
	
	func setup_layer(mesh):
		mesh.set_instance_count(divisions.x*divisions.y)
		var i = 0
		for z in range(divisions.y):
			for x in range(divisions.x):
				var tr = matrix[z][x]
				tr.basis = tr.basis.scaled(Vector3(0,0,0))
				#tr.origin = Vector3(rand_range(-10,10),1,rand_range(-10,10))
				mesh.set_instance_transform(i,tr)
				i += 1
		
	
	func get_layers_handlers():
		while layer_panel.get_child_count():
			var c = layer_panel.get_child(0)
			layer_panel.remove_child(c)
			c.queue_free()
		for lay in self.get_children():
			var g = GrassLayerData.new(lay) #class_ref.new(lay)
			layer_panel.add_child(g)
	
	func _init(panel):
		self.layer_panel = panel
		
		# blank script
		#var script = GDScript.new()
		#script.set_source_code("#!nothing\n\nextends Spatial\n\nfunc _ready():\n\tpass\n\n")
		#set_script(script)

		

# mount layer data
# format:
#	 z  ->	x	->	transform
func setup_layers(grassNode):
	var aabb = grassNode.get_parent().get_aabb()
	var dist = aabb.size / element_step.get_value()
	var mt = Array()
	var zz = aabb.pos.z
	for z in range(ceil(dist.z)):
		var lin = Array()
		var xx = aabb.pos.x
		for x in range(ceil(dist.x)):
			var dt = Transform()
			# random X Z
			var rx = rand_range(-0.98,0.98) * element_step.get_value()
			var rz = rand_range(-0.98,0.98) * element_step.get_value()
			dt.origin = Vector3(xx+rx,0,zz+rz)
			#dt.basis = dt.basis.scaled(Vector3(0,0,0))
			dt.basis = dt.basis.rotated(Vector3(0,1,0), rand_range(-PI,PI))
			lin.push_back(dt)
			xx += element_step.get_value()
		mt.push_back(lin)
		zz += element_step.get_value()
	grassNode.matrix = mt
	grassNode.dist = Vector2(element_step.get_value(),element_step.get_value())
	grassNode.divisions = Vector2(ceil(dist.x),ceil(dist.z))
	grassNode.height = aabb.size.y
	grassNode.begin = aabb.pos
 

###
# Add a spatial to create grass layers
func create_grass_container(parent):
	if not parent.is_type('MeshInstance'):
		return false
	
	var cont = GrassNode.new(layers_panel)
	parent.add_child(cont)
	if get_tree().get_edited_scene_root():
		cont.set_owner(get_tree().get_edited_scene_root())
	else:
		cont.set_owner(parent)
	cont.set_name('_grass')
	#var l1  = MultiMeshInstance.new()
	cont.grass_list = Array()
	setup_layers(cont)
	cont.add_layer(default_mesh)
	cont.get_layers_handlers()
	selected_grass_mesh = cont
	return true



###
# ui


# ui variables
var element_step = SpinBox.new()
var add_control = Button.new()
var sizer = HSlider.new()
var sizer_label = Label.new()
var max_scale = HSlider.new()
var max_scale_label = Label.new()
var strength = HSlider.new()
var strength_label = Label.new()
var decreaser = CheckBox.new()
var eraser = CheckBox.new()
var layers_panel = VBoxContainer.new()
var main_controls = VBoxContainer.new()
var foliage_meshes = OptionButton.new()
var clean_threshold = SpinBox.new()

# mount entire window
func mount_window():
	set_v_size_flags(SIZE_EXPAND_FILL)
	set_h_size_flags(SIZE_FILL)
	#set_size(Vector2(100,500))

	var icon_plane = TextureFrame.new()
	icon_plane.set_texture(icon)
	icon_plane.set_size(Vector2(icon.get_width(),icon.get_height()))
	icon_plane.set_h_size_flags(SIZE_EXPAND_FILL)
	icon_plane.set_tooltip(tr('Help and About'))
	add_child(icon_plane)
	
	var label = Label.new()
	label.set_text(tr("Grass Editor"))
	label.set_end(Vector2(0,0))
	add_child(label)
	
	add_control.set_text('+')
	add_control.set_tooltip(tr('Add foliage'))
	add_control.set_end(Vector2(0,0))
	#add_child(add_control)
	add_control.connect("pressed",self,'add_foliage_control')
	
	foliage_meshes.set_h_size_flags(SIZE_EXPAND_FILL)
	foliage_meshes.connect("item_selected",self,"foliage_mesh_selected")
	#add_child(foliage_meshes)
	
	var hbox = HBoxContainer.new()
	hbox.set_h_size_flags(SIZE_EXPAND_FILL)
	hbox.add_child(foliage_meshes)
	hbox.add_child(add_control)
	add_child(hbox)
	
	main_controls.set_v_size_flags(SIZE_EXPAND_FILL)
	add_child(main_controls)
	
	label = Label.new()
	label.set_text(tr('elements distance'))
	main_controls.add_child(label)
	
	element_step.set_value(0.5)
	element_step.set_editable(true)
	element_step.set_rounded_values(false)
	element_step.set_step(0.25)
	element_step.set_min(0.05)
	element_step.set_max(10)
	element_step.set_end(Vector2(0,0))
	element_step.connect("value_changed",self,'elements_distance_changed')
	main_controls.add_child(element_step)
	
	var divider = HSeparator.new()
	main_controls.add_child(divider)
	
	label = Label.new()
	label.set_text(tr('pencil size'))
	main_controls.add_child(label)
	
	sizer.set_value(0.5)
	sizer.set_rounded_values(false)
	sizer.set_min(0.1)
	sizer.set_max(5)
	sizer.set_step(0.05)
	sizer.set_end(Vector2(0,0))
	sizer.connect("value_changed",self, 'sizer_label_changed')
	
	sizer_label.set_text(str(sizer.get_value()))
	main_controls.add_child(sizer_label)
	main_controls.add_child(sizer)
	
	label = Label.new()
	label.set_text(tr('pencil stretch'))
	main_controls.add_child(label)
	
	strength.set_value(0.8)
	strength.set_rounded_values(false)
	strength.set_min(0.01)
	strength.set_max(1)
	strength.set_step(0.05)
	strength.connect("value_changed",self, 'strength_label_changed')
	
	strength_label.set_text(str(strength.get_value()))
	main_controls.add_child(strength_label)
	main_controls.add_child(strength)
	
	divider = HSeparator.new()
	main_controls.add_child(divider)
	
	decreaser.set_text(tr('Decrease'))
	main_controls.add_child(decreaser)
	
	eraser.set_text(tr('Erase'))
	main_controls.add_child(eraser)
	
	divider = HSeparator.new()
	main_controls.add_child(divider)
	
	label = Label.new()
	label.set_text(tr('max scale'))
	main_controls.add_child(label)
	
	max_scale.set_value(1)
	max_scale.set_rounded_values(false)
	max_scale.set_min(0.01)
	max_scale.set_max(5)
	max_scale.set_step(0.05)
	max_scale.connect("value_changed",self, 'max_scale_label_changed')
	
	max_scale_label.set_text(str(max_scale.get_value()))
	main_controls.add_child(max_scale_label)
	main_controls.add_child(max_scale)
	
	divider = HSeparator.new()
	main_controls.add_child(divider)
	
	hbox = HBoxContainer.new()
	label = Label.new()
	label.set_h_size_flags(SIZE_EXPAND_FILL)
	label.set_text(tr('Layers'))
	hbox.add_child(label)
	
	var add_layer = Button.new()
	add_layer.set_text('+')
	add_layer.set_tooltip(tr('add layer'))
	add_layer.connect("pressed",self,'add_new_layer')
	hbox.add_child(add_layer)
	
	main_controls.add_child(hbox)
	
	hbox = HBoxContainer.new()
	var clean = Button.new()
	clean.set_text(tr('Clean Layers'))
	clean.set_h_size_flags(SIZE_EXPAND_FILL)
	clean.connect("pressed",self,'clean_layers')
	clean_threshold.set_rounded_values(false)
	clean_threshold.set_value(0.02)
	clean_threshold.set_max(10)
	clean_threshold.set_min(0.001)
	clean_threshold.set_step(0.01)
	hbox.add_child(clean)
	hbox.add_child(clean_threshold)
	main_controls.add_child(hbox)
	
	var scrool = ScrollContainer.new()
	scrool.set_enable_h_scroll(false)
	scrool.set_v_size_flags(SIZE_EXPAND_FILL)
	scrool.add_child(layers_panel)
	main_controls.add_child(scrool)
	#scrool.set_size(Vector2(get_parent().get_size().x,200))
	#for i in range(10):
	#	var b = GrassLayerData.new()
	#	#b.set_text(str(i))
	#	layers_panel.add_child(b)
	
	var apply = Button.new()
	apply.set_text(tr('Apply Geometry'))
	apply.set_h_size_flags(SIZE_EXPAND_FILL)
	apply.connect("pressed",self,'make_grass_to_game')
	#main_controls.add_child(apply)
	main_controls.add_child(apply)
	
	main_controls.hide()

func foliage_mesh_selected(id):
	while layers_panel.get_child_count():
		var c = layers_panel.get_child(0)
		layers_panel.remove_child(c)
		c.queue_free()
	#print( foliage_meshes.get_item_metadata(foliage_meshes.get_selected()) )
	#print( foliage_meshes.get_item_text(foliage_meshes.get_selected()) )
	#printt( 'meta',foliage_meshes.get_selected_metadata() )
	foliage_meshes.get_selected_metadata().get_node('_grass').get_layers_handlers()
	selected_grass_mesh = foliage_meshes.get_selected_metadata().get_node('_grass')


var tree_elements_dialog
var tree_elements_view = Tree.new()

func add_foliage_control():
	if tree_elements_dialog==null:
		var d = WindowDialog.new()
		tree_elements_dialog = d
		d.set_size(Vector2(500,400))
		if get_tree().get_current_scene()==null:
			get_node("/root/EditorNode").get_gui_base().add_child(d)
		else:
			get_tree().get_current_scene().add_child(d)
		
		var cont = VBoxContainer.new()
		cont.set_h_size_flags(SIZE_EXPAND_FILL)
		cont.set_v_size_flags(SIZE_EXPAND_FILL)
		cont.set_size(Vector2(500,400))
		d.add_child(cont)
	
		var tree = tree_elements_view
		tree.connect("item_activated",self,"select_tree_element")
		cont.add_child(tree)
		
		var h = HBoxContainer.new()
		h.set_h_size_flags(SIZE_EXPAND_FILL)
		
		var b = Button.new()
		b.set_text(tr('Cancel'))
		h.add_child(b)
		
		b = Button.new()
		b.set_text(tr('Select Item'))
		h.add_child(b)
		b.connect("pressed",self,'select_tree_element')
		
		cont.add_child(h)
		
		tree.set_h_size_flags(SIZE_EXPAND_FILL)
		tree.set_v_size_flags(SIZE_EXPAND_FILL)
	
	tree_elements_view.clear()
	
	var iten = tree_elements_view.create_item()
	iten.set_text(0,tr('Can be make new grass/foliage'))

	var root = get_tree().get_edited_scene_root()
	if root==null:
		root = get_node('/root')
	parse_selection_tree(root,tree_elements_view)
	
	tree_elements_dialog.popup_centered()

func parse_selection_tree(node,tree):
	if node.is_type('MeshInstance'):
		var ok = false
		for nd in node.get_children():
			if nd.is_type('StaticBody'):
				ok = true
			if nd.get_name()=='_grass':
				ok = false
				break
		if ok:
			var item = tree.create_item(tree.get_root())
			item.set_text(0,node.get_name())
			item.set_metadata(0,node )
			
		return
	for nd in node.get_children():
		parse_selection_tree(nd,tree)

func select_tree_element():
	var item =  tree_elements_view.get_selected()
	if item != null:
		create_grass_container( item.get_metadata(0) )
		foliage_meshes.add_item(item.get_metadata(0).get_name())
		foliage_meshes.set_item_metadata(foliage_meshes.get_item_count()-1,item.get_metadata(0))
		foliage_meshes.select(foliage_meshes.get_item_count()-1)
		foliage_mesh_selected(foliage_meshes.get_item_count()-1)
		item.get_metadata(0).get_node('_grass').get_layers_handlers()
		main_controls.show()
	tree_elements_dialog.hide()
	
func add_new_layer():
	if selected_grass_mesh != null:
		selected_grass_mesh.add_layer(default_mesh)
	
func sizer_label_changed(v):
	sizer_label.set_text( str(v).pad_decimals(2) )

func max_scale_label_changed(v):
	max_scale_label.set_text( str(v).pad_decimals(2) )

func strength_label_changed(v):
	strength_label.set_text( str(v).pad_decimals(2) )

func transverse_nodes(node,level):
	var data = ''
	if level > 10:
		return ''
		#var sp = ''
		#for i in range(level):
		#	sp += '\t'
		#return sp + '_MAX_LEVEL\n'
		
	if node.is_type('Camera'):
		var sp = ''
		for i in range(level):
			sp += '\t'
		#if node.get_name()=='@Timer3':
		#	return sp + '_DISCARTED\n'
	
		data = sp + node.get_name() + ":\n"
	for nd in get_children():
		data += transverse_nodes(nd,level + 1)
	return data

func elements_distance_changed(val):
	if not selected_grass_mesh:
		return
	
	setup_layers(selected_grass_mesh)
	for inst in selected_grass_mesh.get_children():
		var mesh = inst.get_multimesh()
		selected_grass_mesh.setup_layer(mesh)


func clean_layers():
	if selected_grass_mesh:
		clean_grass(selected_grass_mesh)


# adjust size of code header licence
func _code_licence_adjust(st,fd,rp,size):
	var lin = st.replace(fd,rp)
	lin = lin.substr(0,lin.length()-1).strip_edges()
	while lin.length()<(size-2):
		lin += " "
	lin += '#'
	return lin

# mont licence header
func make_code(node, grass_data, grass_step, mesh_list, material_list):
	# this step prepare the MIT licence header
	var user = OS.get_environment('USERNAME')
	if not user:
		user = OS.get_environment('LOGNAME')
	var year = OS.get_date().year
	var project_name = 'unknow'
	var file = File.new()
	file.open('res://engine.cfg', File.READ)
	while not file.eof_reached():
		var lin = file.get_line()
		if lin.find('name="')==0:
			var i = lin.find('"')+1
			var e = lin.rfind('"')-i
			project_name = lin.substr(i,e)
	file.close()
	# end of MIT licence header
	
	var file_name = "grass_foliage_generator_" + str(node.get_instance_ID()) + ".gd"
	var mesh_list_str = ""
	for m in mesh_list:
		mesh_list_str += "'" + m + "',"
	mesh_list_str = mesh_list_str.substr(0,mesh_list_str.length()-1)
	var material_list_str = ""
	for m in material_list:
		material_list_str += "'" + m + "',"
	material_list_str = material_list_str.substr(0,material_list_str.length()-1)
	
	var code = ""
	for lin in template_code:
		if lin.find('{%file_name}')>-1:
			lin = _code_licence_adjust(lin,'{%file_name}',file_name,83)
		if lin.find('{%year}')>-1:
			lin = _code_licence_adjust(lin,'{%year}',str(year),83)
		if lin.find('{%copyright_holders}')>-1:
			lin = _code_licence_adjust(lin,'{%copyright_holders}',user,83)
		if lin.find('{%project_name}')>-1:
			lin = _code_licence_adjust(lin,'{%project_name}',project_name,83)
		if lin.find('{%grass_step}')>-1:
			lin = lin.replace('{%grass_step}',grass_step)
		if lin.find('{%mesh_list}')>-1:
			lin = lin.replace('{%mesh_list}',mesh_list_str)
		if lin.find('{%material_list}')>-1:
			lin = lin.replace('{%material_list}',material_list_str)
		if lin.find('{%data_entry}')>-1:
			lin = lin.replace('{%data_entry}',grass_data)
		
		code += lin + "\n"
	
	var script = GDScript.new()
	script.set_name(file_name)
	script.set_source_code(code)
	return script
	
###
# Clean up an mesh grass
func clean_grass(grass):
	var index = 0 # index of tested instance
	for z_lin in grass.matrix:
		for x_lin in z_lin:
			var sz = 0
			var last_inst = null
			for inst in grass.get_children():
				var mm = inst.get_multimesh()
				var s = mm.get_instance_transform(index).basis.get_scale().y
				# pass threshold
				if s<clean_threshold.get_value():
					var tr = mm.get_instance_transform(index)
					tr.basis = tr.basis.scaled(Vector3(0,0,0))
					mm.set_instance_transform(index, tr)
				# if last instance is great then this one
				if last_inst:
					if last_inst.get_instance_transform(index).basis.get_scale().y<=s:
						var tr = mm.get_instance_transform(index)
						tr.basis = tr.basis.scaled(Vector3(0,0,0))
						last_inst.set_instance_transform(index, tr)
						last_inst = mm
				else:
					last_inst = mm
			index += 1
	


#####
# This convert grass editor data in real world data
# From each node named _glass
#	from each MultimeshInstance
#		store the mesh and material
#		store any instance information with scale > clean_threshold
func make_grass_to_game():
	for i in range(foliage_meshes.get_item_count()):
		var mesh = foliage_meshes.get_item_metadata(i).get_node('_grass')
		clean_grass(mesh)
		if mesh != null:
			# setup
			#mesh.set_name('_grass.old')
			var mesh_layers = []
			var material_layers = []
			var data_array = "[\n"
			for inst in mesh.get_children():
				if inst.get_multimesh().get_mesh():
					mesh_layers.push_back( inst.get_multimesh().get_mesh().get_path() )
				else:
					mesh_layers.push_back( '' )
				if inst.get_material_override():
					material_layers.push_back( inst.get_material_override().get_path() )
				else:
					material_layers.push_back( '' )
				if inst.get_multimesh().get_instance_count()>0:
					data_array += "\t["
					for i2 in range(inst.get_multimesh().get_instance_count()):
						var basis = inst.get_multimesh().get_instance_transform(i2).basis
						if basis.get_scale().y>clean_threshold.get_value():
							data_array += str(i2) + ','
							data_array += str(basis.get_euler().y) + ','
							data_array += str(basis.get_scale().y) + ','
							data_array += str(inst.get_multimesh().get_instance_transform(i2).origin.x) + ','
							data_array += str(inst.get_multimesh().get_instance_transform(i2).origin.y) + ','
							data_array += str(inst.get_multimesh().get_instance_transform(i2).origin.z) + ','
				else:
					data_array += "\t[,"
				data_array = data_array.substr(0,data_array.length()-1) + "],\n"
			data_array = data_array.substr(0,data_array.length()-2) + "\n]\n"
			
			mesh.set_name('_grass_old')
			foliage_meshes.get_item_metadata(i).remove_child(mesh)
			
			var g_node = Spatial.new()
			g_node.set_name('_grass')
			g_node.set_script( make_code(g_node, data_array, str(element_step.get_value()), mesh_layers,material_layers) )
			
			foliage_meshes.get_item_metadata(i).add_child(g_node)
			var root = get_tree().get_edited_scene_root()
			if root:
				g_node.set_owner(root)
			mesh.queue_free()

	while  foliage_meshes.get_item_count()>0:
		foliage_meshes.remove_item(0)
	foliage_meshes.set_text('')
	main_controls.hide()
			



###
# Pencil handler, this giant fucntion
func pencil_action(grass,result,space_state,delta):
	#var pos = result.position - result.collider.get_global_transform().origin - grass.begin
	var pos = result.collider.get_global_transform().xform_inv(result.position) - grass.begin
	#print(result.collider.get_global_transform().xform(pos+grass.begin), ' e ', result.position)
	var coord = Vector3( floor(pos.x/grass.dist.x), pos.y, floor(pos.z/grass.dist.y) )
	var amount = 1 + ceil(sizer.get_value()/element_step.get_value())
	var aabb = [coord.x-amount,coord.z-amount,coord.x+amount,coord.z+amount]
	if aabb[0]<0:
		aabb[0]=0
	if aabb[1]<0:
		aabb[1]=0
	if aabb[2]>=grass.divisions.x:
		aabb[2]=grass.divisions.x-1
	if aabb[3]>=grass.divisions.y:
		aabb[3]=grass.divisions.y-1
	#var p_pos = Vector3(result.position.x,0,result.position.z)
	#var p_pos = result.position - result.collider.get_global_transform().origin
	var p_pos = result.collider.get_global_transform().xform_inv(result.position)
	p_pos.y = 0
	var lim_dow = result.collider.get_global_transform().origin.y + grass.get_parent().get_aabb().pos.y - 0.2
	var lim_up = result.collider.get_global_transform().origin.y + grass.get_parent().get_aabb().end.y + 0.2
	for z in range(aabb[1],aabb[3]):
		for x in range(aabb[0],aabb[2]):
			var m = grass.matrix[z][x]
			var p = m.origin
			var p_coord = Vector3(p.x,0,p.z)
			var d = p_pos.distance_squared_to( p_coord )
			if d<=sizer.get_value():
				var i = x + z*grass.divisions.x
				var mesh = grass.get_children()[grass.layer_index].get_multimesh()
				var tr = mesh.get_instance_transform(i)
				var s = 1.0 / d*d
				s = s * (max_scale.get_value() - tr.basis.get_scale().x) * strength.get_value() * 1.5 * delta
				if decreaser.is_pressed():
					s = tr.basis.get_scale().x - s
				else:
					s = tr.basis.get_scale().x + s
				if s>max_scale.get_value():
					s=max_scale.get_value()
				if s<0:
					s = 0
				if eraser.is_pressed():
					tr.basis = m.basis.scaled(Vector3(0,0,0))
				else:
					tr.basis = m.basis.scaled(Vector3(s,s,s))
					#var pt = result.collider.get_global_transform().xform(p+grass.begin)
					var pt = result.collider.get_global_transform().origin + result.collider.get_global_transform().basis.xform(p)
					var r = space_state.intersect_ray( Vector3(pt.x,lim_up,pt.z),Vector3(pt.x,lim_dow,pt.z) )
					if not result.empty() and r.has('position'):
						tr.origin.y = r.position.y - result.collider.get_global_transform().origin.y
					#print(r)
				mesh.set_instance_transform(i,tr)
				grass_to_recalcule = mesh
				#print(tr)
			#printt(d,p,coord,pos)

# this restrict paint to solve performance issues
var pencil_delay = 0
var grass_to_recalcule = null

func _fixed_process(delta):
	if selected_viewport==null:
		return
	
	var main_vp = selected_viewport # get_tree().get_current_scene().get_viewport()
	var space_state
	if main_vp.get_world():
		space_state = main_vp.get_world().get_direct_space_state()
	else:
		space_state = get_tree().get_edited_scene_root().get_world().get_direct_space_state()
	
	var camera = main_vp.get_camera()
	var from = camera.project_ray_origin(mouse_pos-viewport_offset)
	var to = from + camera.project_ray_normal(mouse_pos-viewport_offset) * 100000
	var result = space_state.intersect_ray( from,to )
	
	# draw pencil
	if not result.empty():
		#var d_pos = camera.unproject_position(result.position)
		#printt(d_pos)
		#print(selected_editor_control)
		selected_editor_control.show_pencil(result.position, camera, null, sizer.get_value())
		#if not result.empty():
		#	var parent = result.collider.get_parent()
		#	var grass = parent.get_node('_grass')
		#	if grass:
		#		
	
	if _pencil:
		pencil_delay += delta
		if pencil_delay<0.023:
			return
		
		#printt(mouse_pos,from,to)
		if not result.empty():
			var parent = result.collider.get_parent()
			var grass = parent.get_node('_grass')
			if grass != null:
				#grass = parent.get_node('_grass')
				pencil_action(grass,result,space_state,pencil_delay)
			#var cord = Vector3( floor(pos.x/grass.dist.x), pos.y, floor(pos.z/grass.dist.y) )
			# print(grass.matrix[cord.z][cord.x])
			#print("Hit at point: ",result.collider)
		pencil_delay = 0

func _input(event):
	if event.type == InputEvent.MOUSE_MOTION:
		for c in camera_data:
			if c.has_point(event.global_pos):
				selected_viewport = c.viewport
				selected_editor_control = c.shape
				viewport_offset = c.control.get_global_pos()
				mouse_pos = event.pos
	if event.type == InputEvent.MOUSE_BUTTON:
		if event.button_index==2 and event.is_pressed():
			for c in camera_data:
				if c.has_point(event.global_pos):
					selected_viewport = c.viewport
					selected_editor_control = c.shape
					viewport_offset = c.control.get_global_pos()
					_is_mouse_pressed = event.is_pressed() #not _is_mouse_pressed
					mouse_pos = event.pos
					_pencil = true
					break
		if not event.is_pressed():
			_pencil = false
			selected_viewport = null
			_is_mouse_pressed = false
			if grass_to_recalcule:
				grass_to_recalcule.generate_aabb()
				grass_to_recalcule = null
			
			#print(event.meta)
	if event.type == InputEvent.MOUSE_MOTION and _is_mouse_pressed:
		#print('dragando ', event.pos)
		#mouse_pos = event.pos
		_pencil = true
	

func _enter_tree():
	pass

func _exit_tree():
	pass

func _ready():
	mount_window()
	set_fixed_process(true)
	set_process_input(true)

func _init(_camera_data, _def_mesh, _tc, _ico):
	self.camera_data = _camera_data
	self.default_mesh = _def_mesh
	self.template_code = _tc
	self.icon = _ico


