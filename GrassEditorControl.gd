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

const SPATIAL_SIZE_INI_VAL = 6
const SPATIAL_MIN_SIZE = 2
const SPATIAL_MAX_SIZE = 20
const ELEMENT_STEP_INI_VAL = 0.8
const ELEMENT_STEP_MIN = 0.1
const ELEMENT_STEP_MAX = 10
const PENCIL_SIZE_INI_VAL = 0.5
const PENCIL_SIZE_MIN = 0.1
const PENCIL_SIZE_MAX = 5
const PENCIL_STRETCH_INICIAL_VAL = 0.8
const PENCIL_STRETCH_MIN = 0.05
const PENCIL_STRETCH_MAX = 1

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

const GrassNode = preload('grass_node.gd')

# prepare layer data
# pass to object the basic information of new grass slices
func setup_layers(grassNode):
	
	grassNode.setup(element_step.get_value(),spatial_subdivision_size.get_value())
	grassNode.add_layer(default_mesh)
	grassNode.get_layers_handlers()

###
# Add a spatial to create grass layers
func create_grass_container(parent, layers_count = 1):
	if not parent.is_type('MeshInstance'):
		return false
	
	var cont = GrassNode.new(layers_panel)
	parent.add_child(cont)
	if get_tree().get_edited_scene_root():
		cont.set_owner(get_tree().get_edited_scene_root())
	else:
		cont.set_owner(parent)
	cont.set_name('_grass')
	cont.setup(element_step.get_value(),spatial_subdivision_size.get_value())
	cont.add_layer(default_mesh)
	selected_grass_mesh = cont
	return true



###
# ui

# Layer cusomization dialog

# ui variables
var element_step = SpinBox.new()
var spatial_subdivision_size = SpinBox.new()
var add_control = Button.new()
var pencil_size = HSlider.new()
var pencil_size_label = Label.new()
var max_scale = HSlider.new()
var max_scale_label = Label.new()
var min_scale = HSlider.new()
var min_scale_label = Label.new()
var strength = HSlider.new()
var strength_label = Label.new()
var decreaser = CheckBox.new()
var eraser = CheckBox.new()
var modify = CheckBox.new()
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
	
	hbox = HBoxContainer.new()
	hbox.set_h_size_flags(SIZE_EXPAND_FILL)
	
	var vbox2 = VBoxContainer.new()
	vbox2.set_h_size_flags(SIZE_EXPAND_FILL)
	label = Label.new()
	vbox2.add_child(label)
	
	label.set_text(tr('el. step'))
	label.set_tooltip(tr('elements distance'))
	element_step.set_tooltip(tr('elements distance'))
	element_step.set_value( ELEMENT_STEP_INI_VAL )
	element_step.set_editable(true)
	element_step.set_rounded_values(false)
	element_step.set_step(0.25)
	element_step.set_min(ELEMENT_STEP_MIN)
	element_step.set_max(ELEMENT_STEP_MAX)
	element_step.set_end(Vector2(0,0))
	element_step.connect("value_changed",self,'elements_distance_changed')
	vbox2.add_child(element_step)
	hbox.add_child(vbox2)
	
	vbox2 = VBoxContainer.new()
	vbox2.set_h_size_flags(SIZE_EXPAND_FILL)
	
	label = Label.new()
	label.set_text(tr('Space size'))
	label.set_tooltip(tr('Spatial subdivision size'))
	vbox2.add_child(label)
	spatial_subdivision_size.set_tooltip(tr('Spatial subdivision size'))
	spatial_subdivision_size.set_value( SPATIAL_SIZE_INI_VAL )
	spatial_subdivision_size.set_editable(true)
	spatial_subdivision_size.set_rounded_values(true)
	spatial_subdivision_size.set_step(4)
	spatial_subdivision_size.set_min(SPATIAL_MIN_SIZE)
	spatial_subdivision_size.set_max(SPATIAL_MAX_SIZE)
	spatial_subdivision_size.connect("value_changed",self,'spatial_distance_changed')
	vbox2.add_child(spatial_subdivision_size)
	hbox.add_child(vbox2)
	
	main_controls.add_child(hbox)
	
	var divider = HSeparator.new()
	main_controls.add_child(divider)
	
	label = Label.new()
	label.set_text(tr('pencil size'))
	main_controls.add_child(label)
	
	pencil_size.set_value(PENCIL_SIZE_INI_VAL)
	pencil_size.set_rounded_values(false)
	pencil_size.set_min(PENCIL_SIZE_MIN)
	pencil_size.set_max(PENCIL_SIZE_MAX)
	pencil_size.set_step(0.05)
	pencil_size.set_end(Vector2(0,0))
	pencil_size.connect("value_changed",self, 'sizer_label_changed')
	
	pencil_size_label.set_text(str(pencil_size.get_value()))
	main_controls.add_child(pencil_size_label)
	main_controls.add_child(pencil_size)
	
	label = Label.new()
	label.set_text(tr('pencil stretch'))
	main_controls.add_child(label)
	
	strength.set_value(PENCIL_STRETCH_INICIAL_VAL)
	strength.set_rounded_values(false)
	strength.set_min(PENCIL_STRETCH_MIN)
	strength.set_max(PENCIL_STRETCH_MAX)
	strength.set_step(0.05)
	strength.connect("value_changed",self, 'strength_label_changed')
	
	strength_label.set_text(str(strength.get_value()))
	main_controls.add_child(strength_label)
	main_controls.add_child(strength)
	
	divider = HSeparator.new()
	main_controls.add_child(divider)
	
	modify.set_text(tr('Modyfy mode'))
	modify.set_tooltip(tr("Pencil only change existing data"))
	modify.set_pressed(false)
	modify.connect("toggled",self,"modify_act")
	main_controls.add_child(modify)
	
	decreaser.set_text(tr('Decrease'))
	main_controls.add_child(decreaser)
	
	eraser.set_text(tr('Erase'))
	main_controls.add_child(eraser)
	
	divider = HSeparator.new()
	main_controls.add_child(divider)
	
	# element scale
	hbox = HBoxContainer.new()
	hbox.set_h_size_flags(SIZE_EXPAND_FILL)
	
	vbox2 = VBoxContainer.new()
	vbox2.set_h_size_flags(SIZE_EXPAND_FILL)
	
	label = Label.new()
	label.set_text(tr('min scale'))
	vbox2.add_child(label)
	
	min_scale.set_value(0.0)
	min_scale.set_rounded_values(false)
	min_scale.set_min(0.0)
	min_scale.set_max(4)
	min_scale.set_step(0.05)
	min_scale.connect("value_changed",self, 'min_scale_label_changed')
	
	min_scale_label.set_text(str(min_scale.get_value()))
	vbox2.add_child(min_scale_label)
	vbox2.add_child(min_scale)
	hbox.add_child(vbox2)
	
	vbox2 = VBoxContainer.new()
	vbox2.set_h_size_flags(SIZE_EXPAND_FILL)
	
	label = Label.new()
	label.set_text(tr('max scale'))
	vbox2.add_child(label)
	
	max_scale.set_value(1)
	max_scale.set_rounded_values(false)
	max_scale.set_min(0.01)
	max_scale.set_max(5)
	max_scale.set_step(0.05)
	max_scale.connect("value_changed",self, 'max_scale_label_changed')
	
	max_scale_label.set_text(str(max_scale.get_value()))
	vbox2.add_child(max_scale_label)
	vbox2.add_child(max_scale)
	hbox.add_child(vbox2)
	
	main_controls.add_child(hbox)
	
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
	
	# layer panel
	var scroll = ScrollContainer.new()
	scroll.set_enable_h_scroll(false)
	scroll.set_v_size_flags(SIZE_EXPAND_FILL)
	scroll.set_h_size_flags(SIZE_EXPAND_FILL)
	layers_panel.set_h_size_flags(SIZE_EXPAND_FILL)
	scroll.add_child(layers_panel)
	main_controls.add_child(scroll)

	
	hbox = HBoxContainer.new()
	var clean = Button.new()
	clean.set_text(tr('Clean Layers'))
	clean.set_h_size_flags(SIZE_EXPAND_FILL)
	clean.connect("pressed",self,'clean_layers')
	clean_threshold.set_rounded_values(false)
	clean_threshold.set_value(0.08)
	clean_threshold.set_max(10)
	clean_threshold.set_min(0.001)
	clean_threshold.set_step(0.01)
	hbox.add_child(clean)
	hbox.add_child(clean_threshold)
	main_controls.add_child(hbox)
	
	
	divider = HSeparator.new()
	main_controls.add_child(divider)
	
	var randomizer = Button.new()
	randomizer.set_text(tr('Rand visible layers'))
	randomizer.set_h_size_flags(SIZE_EXPAND_FILL)
	randomizer.connect("pressed",self,'randomize_visible_layers_act')
	main_controls.add_child(randomizer)
	
	divider = HSeparator.new()
	main_controls.add_child(divider)
	
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
	foliage_meshes.get_selected_metadata().get_node('_grass').get_layers_handlers()
	selected_grass_mesh = foliage_meshes.get_selected_metadata().get_node('_grass')
	#print(selected_grass_mesh.spatial_subdivision_size)
	spatial_subdivision_size.set_value(selected_grass_mesh.spatial_subdivision_size)

func modify_act(value):
	eraser.set_disabled(value)

# constos for initialize mesh

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
		
		var warning = Label.new()
		warning.set_h_size_flags(SIZE_EXPAND_FILL)
		warning.set_text(tr('(*) Items marked to convert to editable, will be lost final data and need be save again.'))
		cont.add_child(warning)
		
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
		var exists = false
		for nd in node.get_children():
			if nd.is_type('StaticBody'):
				ok = true
			if nd.get_name()=='_grass':
				# if already exists a _grass
				if ok:
					ok = false
					exists = false
					if nd.get_script().has_source_code():
						if nd.get_script().get_source_code().length()>0:
							ok = true
							exists = true
				#ok = false
				#break
		if ok:
			var name = node.get_name()
			var item = tree.create_item(tree.get_root())
			if exists:
				name += tr(' [convert to editable (*)]')
			item.set_text(0,name)
			item.set_metadata(0,node )
			
		return
	for nd in node.get_children():
		parse_selection_tree(nd,tree)

# select a tree element, and check if already exist a _grass node inside
# in positive case, call the convertion function
func select_tree_element():
	var previus_data = ''
	var layers_count = 1
	var item =  tree_elements_view.get_selected()
	
	if item != null:
		if item.get_metadata(0).get_node('_grass') != null:
			var nd = item.get_metadata(0).get_node('_grass')
			nd.set_name('_grass.removed')
			previus_data = nd.get_script().get_source_code()
			layers_count = nd.get_child_count()
			nd.get_parent().remove_child(nd)
			nd.queue_free()
			#if layers_count<1:
			#	layers_count = 1
			layers_count = 0
			
		create_grass_container( item.get_metadata(0), layers_count )
		foliage_meshes.add_item(item.get_metadata(0).get_name())
		foliage_meshes.set_item_metadata(foliage_meshes.get_item_count()-1,item.get_metadata(0))
		foliage_meshes.select(foliage_meshes.get_item_count()-1)
		foliage_mesh_selected(foliage_meshes.get_item_count()-1)
		
		# if previs data exists
		if not previus_data.empty():
			var nd = item.get_metadata(0).get_node('_grass')
			var c = nd.get_child(0)
			nd.remove_child(c)
			c.queue_free()
			nd.convert_code_to_data(previus_data)
		
		# show layer handlers
		item.get_metadata(0).get_node('_grass').get_layers_handlers()
		main_controls.show()
		
		spatial_subdivision_size.set_value(selected_grass_mesh.spatial_subdivision_size)
		
	tree_elements_dialog.hide()
	
func add_new_layer():
	if selected_grass_mesh != null:
		selected_grass_mesh.add_layer(default_mesh)
	
func sizer_label_changed(v):
	pencil_size_label.set_text( str(v).pad_decimals(2) )

func min_scale_label_changed(v):
	if v>=max_scale.get_value():
		v = max_scale.get_value() - max_scale.get_step()
		min_scale.set_value(v)
		if v<0:
			v = 0
	min_scale_label.set_text( str(v).pad_decimals(2) )

func max_scale_label_changed(v):
	if v<=min_scale.get_value():
		v = min_scale.get_value() + min_scale.get_step()
		max_scale.set_value(v)
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

# TODO: change it to a progress system
func elements_distance_changed(val):
	if not selected_grass_mesh:
		return
	
	setup_layers(selected_grass_mesh)

# TODO: change it to a progress system
func spatial_distance_changed(val):
	if not selected_grass_mesh:
		return
	setup_layers(selected_grass_mesh)

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

###
# Clean up an mesh grass
func sort_multimesh(m1,m2):
	var t1 = m1[0].get_instance_transform(m1[1])
	var t2 = m2[0].get_instance_transform(m2[1])
	return t1.basis.get_scale().y<t2.basis.get_scale().y

###
# set elements that under threshold scale and elements
# less scale on override others to a zero scale
func clean_grass(grass):
	var index
	for mz in range(grass.matrix.size()):
		for mx in range(grass.matrix[0].size()):
			var inst_index = 0
			for zz in range(ceil(grass.spatial_subdivision_size/grass.dist.y)):
				for xx in range(ceil(grass.spatial_subdivision_size/grass.dist.x)):
					var test_layers = []
					for layer_index in range(grass.layer_meshes.size()):
						if grass.matrix[mz][mx].size()>layer_index:
							var multimesh_i_A = grass.matrix[mz][mx][layer_index]
							if multimesh_i_A:
								var multimesh_A = multimesh_i_A.get_multimesh()
								var it = multimesh_A.get_instance_transform(inst_index)
								var s = it.basis.get_scale().y
								if s>0 and s<clean_threshold.get_value():
									it.basis = it.basis.scaled(Vector3(0,0,0))
									multimesh_A.set_instance_transform(inst_index,it)
								else:
									test_layers.append([multimesh_A,inst_index])
								index = {index=inst_index,matrix={x=mx,z=mz}}
					test_layers.sort_custom(self,'sort_multimesh')
					while test_layers.size()>1:
						var it = test_layers[0][0].get_instance_transform(test_layers[0][1])
						it.basis = it.basis.scaled(Vector3(0,0,0))
						test_layers[0][0].set_instance_transform(test_layers[0][1],it)
						test_layers.remove(0)
						
					inst_index += 1


###
# This tool randomize instance under visible layers
# note that the individual layer can be a randomization
# factor from 1 to 100 to control distribuition
func randomize_visible_layers_act():
	if selected_grass_mesh:
		randomize_visible_layers(selected_grass_mesh)

func randomize_visible_layers(grass):
	var old_layer_index = grass.layer_index
	var aabb = grass.get_parent().get_aabb()
	var ini = Vector3(-aabb.size.x/2,0,-aabb.size.z/2)
	var end = Vector3(aabb.size.x/2,0,aabb.size.z/2)
	var zz = ini.z
	while zz<end.z:
		var xx = ini.x
		while xx<end.x:
			var layers = []
			var scale = 0
			var pos = Vector3()
			for layer_index in range(grass.layer_meshes.size()):
				grass.layer_index = layer_index
				var res = grass.localize(Vector3(xx,0,zz))
				var s = res.trans.basis.get_scale().y
				if s>0:
					if s>scale:
						scale = s
				if res.trans.origin.y != 0 or pos==Vector3():
						pos = res.trans.origin
				layers.append(res)
			if layers.size()>0:
				# select
				var ob = -1
				while true:
					ob = randi()%layers.size()
					var sd = layers[ob].instance.get_parent().get_meta('_data').randomization
					if sd<1:
						if randf()>sd:
							ob = -1
					if ob>-1:
						break
				# set not selected instance to zero size
				for i in range(layers.size()):
					var ind = layers[i].index
					var o = layers[i].mesh.get_instance_transform(ind)
					if i!=ob:
						layers[i].mesh.set_instance_transform(ind,Transform(Matrix3().scaled(Vector3(0,0,0)), pos)) #o.origin
					else:
						layers[i].mesh.set_instance_transform(ind,Transform(layers[i].o_trans.basis.scaled(Vector3(scale,scale,scale)),pos))#layers[i].trans.origin
			xx += grass.dist.x
		zz += grass.dist.x
	# aabb
	for sp in grass.get_children():
		for mi in sp.get_children():
			mi.get_multimesh().generate_aabb()
	grass.layer_index = old_layer_index
	#print(grass.localize(Vector3(0,0,0)))


### 
# Mont script to grass node
# Licence header uses system and project configuration
#
func make_code(node, grass_data, str_mesh_data, layer_names, randomization, binary_filename):
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
	
	var grass_step = str(element_step.get_value())
	
	var file_name = "grass_foliage_generator_" + str(node.get_instance_ID()) + ".gd"
	
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
			lin = lin.replace('{%mesh_list}',str_mesh_data)
		if lin.find('{%data_entry}')>-1:
			lin = lin.replace('{%data_entry}',grass_data)
		if lin.find('{%randomization}')>-1:
			lin = lin.replace('{%randomization}',randomization)
		if lin.find('{%division_size}')>-1:
			var v = str(int(spatial_subdivision_size.get_value()))
			lin = lin.replace('{%division_size}', v+","+v+","+v )
		if lin.find('{%layer_names}')>-1:
			lin = lin.replace('{%layer_names}',layer_names)
		if lin.find('{%binary_filename}')>-1:
			lin = lin.replace('{%binary_filename}',binary_filename)
		code += lin + "\n"
	
	var script = GDScript.new()
	script.set_name(file_name)
	script.set_source_code(code)
	return script



#####
# This convert grass editor data in real world data
# From each node named _glass
#	from each MultimeshInstance
#		store the mesh and material
#		store any instance information with scale > clean_threshold
func make_grass_to_game():
	for i in range(foliage_meshes.get_item_count()):
		var grass = foliage_meshes.get_item_metadata(i).get_node('_grass')
		if grass:
			clean_grass(grass)
			var randomization = ""
			var str_mesh_layers_data = "\n"
			for sp in grass.get_children():
				var data = sp.get_meta('_data')
				randomization += str(data.randomization) + ","
				var data1 = "\t[\n"
				for il in range(data.meshes.size()):
					var ms = data.meshes[il]
					var mt = data.materials[il]
					if ms == null:
						ms = ''
					if mt == null:
						mt = ''
					var s = "{mesh='" + ms + "',"
					s += "far=" + str(data.ranges[il][0]) + ","
					s += "near=" + str(data.ranges[il][1]) + ","
					s += "resource=null,lods=[],material=null,"
					s += "material_override='" + mt + "'},\n"
					data1 += "\t\t" + s
				str_mesh_layers_data += data1.substr(0,data1.length()-2) + "\n\t],\n"
			str_mesh_layers_data = str_mesh_layers_data.substr(0,str_mesh_layers_data.length()-2) + "\n"
			
			var binary = File.new()
			var p = grass.get_parent().get_name()
			p = p.replace(' ','_').replace('.','_')
			var binary_filename = 'user://.grass_editor_only_'+p+'_'+str(grass.get_parent().get_instance_ID())
			binary.open(binary_filename, File.WRITE )
			
			# data
			var data = "\n"
			for layer_index in range(grass.get_child_count()):
				data += "\t[\n"
				for zz in grass.matrix:
					for xx in zz:
						if xx.size() == 0:
							var s = ""
							#for i2 in range(ceil(grass.get_parent().get_aabb().size.x/grass.spatial_subdivision_size)):
							#	s += "\t\t[]#zero,\n"
							#data += s.substr(0,s.length()-2) + ",\n"
							data += "\t\t[],\n"
							binary.store_32(0)
						else:
							if layer_index>=xx.size() or xx[layer_index] == null:
								data += "\t\t[],\n"
								binary.store_32(0)
							else:
								data += "\t\t["
								var data1 = ""
								var mm = xx[layer_index].get_multimesh()
								binary.store_32(mm.get_instance_count())
								for ind in range(mm.get_instance_count()):
									var tr = mm.get_instance_transform(ind)
									if tr.basis.get_scale().y>0:
										# scale
										var s = tr.basis.get_scale().y
										data1 += str(s).pad_decimals(2) + ','
										binary.store_float(s)
										# rotation
										var e = tr.basis.get_euler().y
										data1 += str(e).pad_decimals(2) + ','
										binary.store_float(e)
										# x
										var n = tr.origin.x
										data1 += str(n) + ','
										binary.store_float(n)
										# y
										n = tr.origin.y
										data1 += str(n) + ','
										binary.store_float(n)
										# z
										n = tr.origin.z
										data1 += str(n) + ','
										binary.store_float(n)
									else:
										binary.store_float(0)
										binary.store_float(0)
										binary.store_float(0)
										binary.store_float(0)
										binary.store_float(0)
								
								data += data1.substr(0,data1.length()-2) + "],\n"
				data = data.substr(0,data.length()-2) + "\n\t],\n"
			
			data = data.substr(0,data.length()-2) + "\n"
			
			binary.close()
			binary = null
			
			#printt(grass.matrix.size(),grass.matrix[0].size())
			#var file = File.new()
			#file.open("user://data.txt",File.WRITE)
			#file.store_string(data)
			#file.close()
			#print('file w')
			
			# names
			var layer_names = ""
			for sp in grass.get_children():
				layer_names += "'"+sp.get_name() + "',"
			layer_names = layer_names.substr(0,layer_names.length()-1)
			
			randomization = randomization.substr(0,randomization.length()-1)
			
			# hand nodes
			grass.set_name('_grass_old')
			foliage_meshes.get_item_metadata(i).remove_child(grass)
			
			var g_node = Spatial.new()
			g_node.set_name('_grass')
			g_node.set_script( make_code(g_node, data, str_mesh_layers_data, layer_names, randomization, binary_filename) )
			
			foliage_meshes.get_item_metadata(i).add_child(g_node)
			var root = get_tree().get_edited_scene_root()
			if root:
				g_node.set_owner(root)
			grass.queue_free()
			
	while  foliage_meshes.get_item_count()>0:
		foliage_meshes.remove_item(0)
	foliage_meshes.set_text('')
	main_controls.hide()
	

# pencil extra features
var meshes_to_update = Dictionary()


###
# Pencil handler, this giant fucntion
func pencil_action(grass,result,space_state,delta):
	var d_offset = grass.get_parent().get_aabb().pos + grass.get_parent().get_aabb().size/2
	var p_pos = result.collider.get_global_transform().xform_inv(result.position) - d_offset
	var plan_pos = Vector3(result.position.x,0,result.position.z)
	p_pos.y = 0
	#var position_plane = p_pos # Vector3(result.position.x,0,result.position.z) - d_offset
	
	#printt(p_pos, p_pos - grass.get_parent().get_aabb().size/2)
	var lim_dow = result.collider.get_global_transform().origin.y + grass.get_parent().get_aabb().pos.y - 0.2
	var lim_up = result.collider.get_global_transform().origin.y + grass.get_parent().get_aabb().end.y + 0.2
	
	var z = p_pos.z - pencil_size.get_value()*2
	while z<(p_pos.z + pencil_size.get_value()*2):
		var x = p_pos.x - pencil_size.get_value()*2
		while x<(p_pos.x + pencil_size.get_value()*2):
			var p_coord = Vector3(x,0,z)
			var res = grass.localize(p_coord)
			if not res.empty():
				if res.mesh:
					#var pw_pos = res.instance.get_global_transform().xform_inv(res.o_trans.origin)
					var pw_pos = res.instance.get_global_transform().origin + res.o_trans.origin
					var pp_pos = res.instance.get_global_transform().xform(res.o_trans.origin) + d_offset
					
					#printt(res.instance.get_global_transform(), res.instance.get_global_transform().xform_inv(res.o_trans.origin))
					var d = Vector3(pw_pos.x,0,pw_pos.z).distance_to(plan_pos)
					if d<=(pencil_size.get_value()):
						var s = 1.0 / d*d
						s = s * (max_scale.get_value() - res.trans.basis.get_scale().x) * strength.get_value() * 1.5 * delta
						if decreaser.is_pressed():
							s = res.trans.basis.get_scale().x - s
						else:
							s = res.trans.basis.get_scale().x + s
						# scale check
						if s>max_scale.get_value():
							s=max_scale.get_value()
						if s<0:
							s = 0
						if min_scale.get_value()>0 and s<min_scale.get_value():
							s = min_scale.get_value()
						# eraser check
						if eraser.is_pressed():
							if not modify.is_pressed():
								res.trans.basis = res.o_trans.basis.scaled(Vector3(0,0,0))
						else:
							var r = space_state.intersect_ray( Vector3(pw_pos.x,lim_up,pw_pos.z),Vector3(pw_pos.x,lim_dow,pw_pos.z) )
							if not result.empty() and r.has('position'):
								if not modify.is_pressed():
									res.trans.origin.y = r.position.y - result.collider.get_global_transform().origin.y
									res.trans.basis = res.o_trans.basis.scaled(Vector3(s,s,s))
								else: # make more tests
									if res.trans.basis.get_scale().y>0:
										res.trans.origin.y = r.position.y - result.collider.get_global_transform().origin.y
										res.trans.basis = res.o_trans.basis.scaled(Vector3(s,s,s))
						res.mesh.set_instance_transform(res.index,res.trans)
						if not meshes_to_update.has(res.mesh.get_rid()):
							meshes_to_update[res.mesh.get_rid()] = res.mesh
			
			x += element_step.get_value()
		z += element_step.get_value()
	
	#printt(res.instance.get_global_transform().xform(res.o_trans.origin), result.position)		
	
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
		if get_tree().get_edited_scene_root() == null:
			return
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
		selected_editor_control.show_pencil(result.position, camera, null, pencil_size.get_value())
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
				if grass.get('is_grass'):
					pencil_action(grass,result,space_state,pencil_delay)
			#var cord = Vector3( floor(pos.x/grass.dist.x), pos.y, floor(pos.z/grass.dist.y) )
			# print(grass.matrix[cord.z][cord.x])
			#print("Hit at point: ",result.collider)
		pencil_delay = 0

func _input(event):
	randi()
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
			#if grass_to_recalcule:
			#	grass_to_recalcule.generate_aabb()
			#	grass_to_recalcule = null
			for m in meshes_to_update:
				meshes_to_update[m].generate_aabb()
			meshes_to_update.clear()
			
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


