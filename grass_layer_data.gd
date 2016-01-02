#########################################################################
# grass_layer_data.gd                                                   #
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

extends VBoxContainer


const LayerController = preload('layer_controller.gd')
const CURSOR_IMG = preload('resources/cursor_arrow.png')
const CURSOR_IMG_DISABLED = preload('resources/cursor_arrow_disabled.png')
const EYE_IMG = preload('resources/eye.png')
const EYE_IMG_DISABLED = preload('resources/eye_disabled.png')

var material
var mesha
var ref

var mesh_bt
var mat_bt
var layer_name = Label.new()

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

func show_hide_layer(value):
	if value:
		ref.show()
	else:
		ref.hide()

func show_layer_props():
	var lc = LayerController.new(self.ref,layer_name)
	lc.set_size(Vector2(500,400))
	if get_tree().get_current_scene()==null:
		get_node("/root/EditorNode").get_gui_base().add_child(lc)
	else:
		get_tree().get_current_scene().add_child(lc)
	lc.popup_centered()

func _ready():
	set_h_size_flags(SIZE_EXPAND_FILL)
	
	var hbox = HBoxContainer.new()
	var bt = Button.new()
	
	hbox.set_h_size_flags(SIZE_EXPAND_FILL)
	
	var img = TextureButton.new()
	img.set_size(Vector2(24,24))
	img.set_normal_texture(CURSOR_IMG_DISABLED)
	img.set_pressed_texture(CURSOR_IMG)
	img.set_toggle_mode(true)
	img.connect("pressed",self,"active_this_layer")
	if self.ref.get_parent().layer_index == self.get_index():
		img.set_pressed(true)
	hbox.add_child(img)
	
	img = TextureButton.new()
	img.set_size(Vector2(24,24))
	img.set_normal_texture(EYE_IMG_DISABLED)
	img.set_pressed_texture(EYE_IMG)
	img.set_toggle_mode(true)
	img.connect("toggled",self,"show_hide_layer")
	if ref.is_visible():
		img.set_pressed(true)
	else:
		img.set_pressed(false)
	hbox.add_child(img)
	
	layer_name.set_h_size_flags(SIZE_EXPAND_FILL)
	layer_name.set_text(ref.get_name())
	hbox.add_child(layer_name)
	
	#bt.set_text('X')
	#bt.set_tooltip(tr('Remove Layer'))
	#bt.connect("pressed",self,'remove_layer')
	bt.set_text(tr('Edit'))
	bt.set_tooltip(tr('Edit layer properties'))
	bt.connect("pressed",self,"show_layer_props")
	hbox.add_child(bt)
	
	add_child(hbox)
	
	add_child( HSeparator.new() )

func _init(link):
	self.ref = link

