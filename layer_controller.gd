#########################################################################
# layer_controller.gd                                                   #
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

extends WindowDialog

# preload class to resource dialog
const OpenResource = preload('open_resource.gd')


##
# conteiner for LoD level in LoD panel
#
class Layer_LoD_Panel extends VBoxContainer:
	var bt_mesh = Button.new()
	var bt_material = Button.new()
	var near = SpinBox.new()
	var far = SpinBox.new()
	var main
	
	func load_resource_dialog(callback,tp = "Mesh"):
		var o = OpenResource.new(self,callback,tp)
		o.set_size(Vector2(450,400))
		if get_tree().get_current_scene()==null:
			get_node("/root/EditorNode").get_gui_base().add_child(o)
		else:
			get_tree().get_current_scene().add_child(o)
		o.popup_centered()
	
	func load_mesh_dialog():
		load_resource_dialog("load_mesh")
	
	func load_mesh(path):
		var i = path.rfind('/')
		var name = path.substr(i+1,path.length()-i)
		bt_mesh.set_text(name)
		bt_mesh.set_meta('_path',path)
		main.update_data()
	
	func load_material_dialog():
		load_resource_dialog("load_material","Material")
	
	func load_material(path):
		var i = path.rfind('/')
		var name = path.substr(i+1,path.length()-i)
		bt_material.set_text(name)
		bt_material.set_meta('_path',path)
		main.update_data()
	
	func spin_changed(v):
		main.normalize_lods()
	
	func _init(main):
		self.main = main
		var hbox1 = HBoxContainer.new()
		hbox1.set_h_size_flags(SIZE_EXPAND_FILL)
		var vbox1 = VBoxContainer.new()
		vbox1.set_h_size_flags(SIZE_EXPAND_FILL)
		var hbox2 = HBoxContainer.new()
		hbox2.set_h_size_flags(SIZE_EXPAND_FILL)
		var lbl = Label.new()
		
		bt_mesh.set_name('bt_mesh')
		lbl.set_text(tr('mesh') + ": ")
		hbox2.add_child(lbl)
		bt_mesh.set_h_size_flags(SIZE_EXPAND_FILL)
		bt_mesh.set_text('default')
		bt_mesh.connect("pressed",self, "load_mesh_dialog")
		hbox2.add_child(bt_mesh)
		vbox1.add_child(hbox2)
		
		hbox2 = HBoxContainer.new()
		hbox2.set_h_size_flags(SIZE_EXPAND_FILL)
		lbl = Label.new()
		bt_material.set_name('bt_material')
		bt_material.set_h_size_flags(SIZE_EXPAND_FILL)
		bt_material.connect("pressed",self, "load_material_dialog")
		lbl.set_text(tr('material') + ": ")
		hbox2.add_child(lbl)
		bt_material.set_text('')
		hbox2.add_child(bt_material)
		vbox1.add_child(hbox2)
		hbox1.add_child(vbox1)
		
		vbox1 = VBoxContainer.new()
		#vbox1.set_h_size_flags(SIZE_EXPAND_FILL)
		hbox2 = HBoxContainer.new()
		lbl = Label.new()
		lbl.set_h_size_flags(SIZE_EXPAND_FILL)
		lbl.set_text(tr('Range begin'))
		hbox2.add_child(lbl)
		
		near.set_name('near')
		near.set_step(1)
		near.set_rounded_values(true)
		near.set_min(0)
		near.connect("value_changed",self,"spin_changed")
		hbox2.add_child(near)
		vbox1.add_child(hbox2)
		hbox2 = HBoxContainer.new()
		lbl = Label.new()
		lbl.set_h_size_flags(SIZE_EXPAND_FILL)
		lbl.set_text(tr('Range end'))
		hbox2.add_child(lbl)
		
		far.set_name('far')
		far.set_step(1)
		far.set_rounded_values(true)
		far.set_min(0)
		far.connect("value_changed",self,"spin_changed")
		hbox2.add_child(far)
		vbox1.add_child(hbox2)
		hbox1.add_child(vbox1)
		add_child(hbox1)
		var sep = HSeparator.new()
		add_child(sep)


var statics = Label.new()
var lod_panels = VBoxContainer.new()
var randomization = SpinBox.new()
var name = LineEdit.new()
var ref
var text_link

# LoD levels into the rules
func normalize_lods():
	var last_lod
	for lod in lod_panels.get_children():
		# minimal values
		if lod.near.get_value()>lod.far.get_value():
			lod.far.set_value(lod.near.get_value())
		if lod.far.get_value()<lod.near.get_value():
			lod.near.set_value(lod.far.get_value())
		if lod.near.get_value()<0:
			lod.near.set_value(0)
		if lod.far.get_value()<0:
			lod.far.set_value(0)
		# hierarchy
		if last_lod:
			if lod.near.get_value()<last_lod.far.get_value():
				lod.near.set_value(last_lod.far.get_value())
			if lod.near.get_value()>last_lod.far.get_value():
				lod.near.set_value(last_lod.far.get_value())
			if lod.far.get_value()<lod.near.get_value():
					lod.far.set_value(last_lod.far.get_value())
		last_lod = lod
	

# handler to add new Lod level data
func add_lod_control():
	var lod = Layer_LoD_Panel.new(self)
	lod_panels.add_child(lod)
	normalize_lods()
	return lod

# when start dialog, this copy data from layer to dialog
func update_structure():
	var data = ref.get_meta('_data')
	for i in range(data.meshes.size()):
		var path = data.meshes[i]
		var mat = data.materials[i]
		var ranges = data.ranges[i]
		var lod = add_lod_control()
		if path:
			var ind = path.rfind('/')
			lod.bt_mesh.set_text(path.substr(ind+1,path.length()-ind))
			lod.bt_mesh.set_meta('_path',path)
		if mat:
			var ind = mat.rfind('/')
			lod.bt_material.set_text(mat.substr(ind+1,mat.length()-ind))
			lod.bt_material.set_meta('_path',mat)
		lod.near.set_value(ranges[0])
		lod.far.set_value(ranges[1])
	randomization.set_value(ceil(100*data.randomization))
	#count elements NOTE: removed by performance
	#var num = 0
	#for sp in ref.get_children():
	#	num += sp.get_multimesh().get_instance_count()
	#statics.set_text(tr("Element count: " + str(num)))
	name.set_text(ref.get_name())

# update layer data
func update_data():
	if lod_panels.get_child_count()>0:
		var lod = lod_panels.get_child(0)
		var mesh = lod.bt_mesh.get_meta('_path')
		var mat = lod.bt_material.get_meta('_path')
		var near = lod.near.get_value()
		var far = lod.near.get_value()
		if mesh:
			var r = ResourceLoader.load(mesh,"Mesh")
			for m in ref.get_children():
				m.get_multimesh().set_mesh(r)
			ref.get_parent().layer_meshes[ref.get_index()][0] = r
		if mat:
			var r = ResourceLoader.load(mat,"Material")
			for m in ref.get_children():
				m.set_material_override(r)
			ref.get_parent().layer_materials[ref.get_index()][0] = r
		#for m in ref.get_children():
		#	m.set_draw_range_begin(near)
		#	m.set_draw_range_end(far)
		var data = {meshes=[],materials=[],ranges=[],randomization=self.randomization.get_value()*0.01}
		for lod in lod_panels.get_children():
			data.meshes.append(lod.bt_mesh.get_meta('_path'))
			data.materials.append(lod.bt_material.get_meta('_path'))
			data.ranges.append( [abs(lod.near.get_value()),abs(lod.far.get_value())] )
		ref.set_meta('_data',data)

func name_changed_act(name):
	ref.set_name(name)
	text_link.set_text(name)

func _ready():
	var cont = VBoxContainer.new()
	cont.set_h_size_flags(SIZE_EXPAND_FILL)
	cont.set_v_size_flags(SIZE_EXPAND_FILL)
	cont.set_size(get_size()-Vector2(4,4))
	cont.set_pos(Vector2(2,2))
	add_child(cont)
	
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.set_text(tr('Name') + ": ")
	hbox.add_child(lbl)
	name.set_h_size_flags(SIZE_EXPAND_FILL)
	name.connect("text_changed",self,"name_changed_act")
	hbox.add_child(name)
	cont.add_child(hbox)
	
	statics.set_h_size_flags(SIZE_EXPAND_FILL)
	cont.add_child(statics)
	
	hbox = HBoxContainer.new()
	hbox.set_h_size_flags(SIZE_EXPAND_FILL)
	lbl = Label.new()
	lbl.set_text(tr('Ramdomization factor (%) '))
	hbox.add_child(lbl)
	randomization.set_rounded_values(true)
	randomization.set_step(1)
	randomization.set_min(1)
	randomization.set_max(100)
	randomization.set_tooltip(tr('This is only used from "Rand visible layers" tool'))
	hbox.add_child(randomization)
	cont.add_child(hbox)
	
	lbl = Label.new()
	lbl.set_text(tr('LoD meshes'))
	cont.add_child(lbl)
	
	hbox = HBoxContainer.new()
	hbox.set_h_size_flags(SIZE_EXPAND_FILL)
	var sep = HSeparator.new()
	sep.set_h_size_flags(SIZE_EXPAND_FILL)
	hbox.add_child(sep)
	var moreLayer = Button.new()
	moreLayer.set_text(tr('Add LoD mesh'))
	moreLayer.connect("pressed",self,"add_lod_control")
	hbox.add_child(moreLayer)
	cont.add_child(hbox)
	
	lod_panels.set_h_size_flags(SIZE_EXPAND_FILL)
	
	var scroll = ScrollContainer.new()
	scroll.set_enable_h_scroll(false)
	scroll.set_v_size_flags(SIZE_EXPAND_FILL)
	scroll.add_child(lod_panels)
	cont.add_child(scroll)
	
	lbl = Label.new()
	lbl.set_h_size_flags(SIZE_EXPAND_FILL)
	#lbl.set_v_size_flags(SIZE_EXPAND)
	lbl.set_text(tr('Use different meshes to alternate in range views.'))
	cont.add_child(lbl)
	
	set_title(tr('Layer data'))
	
	update_structure()
	#add_lod_control()


func _init(ref, text_link):
	connect("popup_hide",self,"update_data")
	self.ref = ref
	self.text_link = text_link
	
	

