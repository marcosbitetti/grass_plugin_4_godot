#########################################################################
# grass_node.gd                                                         #
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

extends Spatial


const GrassLayerData = preload('grass_layer_data.gd')

var matrix = []
var dist = Vector2(0.5,0.5)
var divisions = Vector2() # divisions of containers in parent
var spatial_subdivision_size = 10
var height = 1
var begin = Vector3()
var layer_index = 0
var layer_meshes = []
var layer_materials = []
var layer_panel
var is_grass = true # this is used in editor to prevent click in not editable grass

####
# this setup and reset all data
#
func setup(dist, spatial_subdivision_size):
	
	for i in range(get_child_count()):
		var c = get_child(0)
		remove_child(c)
		c.queue_free()
	
	var aabb = get_parent().get_aabb()
	self.dist = Vector2(dist,dist)
	self.spatial_subdivision_size = spatial_subdivision_size
	self.divisions = Vector2(ceil(aabb.size.x / spatial_subdivision_size),ceil(aabb.size.z / spatial_subdivision_size))
	self.height = aabb.size.y
	self.begin = aabb.pos
	# mount multidimensional array to store data
	var lin = Array()
	for z in range(ceil(aabb.size.z / spatial_subdivision_size)):
		var col = Array()
		for x in range(ceil(aabb.size.x / spatial_subdivision_size)):
			col.append( [] )
		lin.append(col)
	self.matrix = lin
	self.layer_meshes.clear()
	self.layer_materials.clear()

# get a point and return a dictionary with multimesh and instance index to transform
# return value is a dict with:
#		grid	= vector3 with the main grid index position x,z
#		mat		= vector3 with the local index position of element x,z
#		instance= the mesh instaqnce affected
#		index	= the instance index of static mesh to be managed
#		trans	= the transform of instance
#		o_trans = the original transform of instance
func localize(point,use_layer_index=-1):
	var aabb = get_parent().get_aabb()
	var maabb = aabb.size * 0.5
	var _point = point + maabb
	var grid_pos = Vector3( floor(_point.x/spatial_subdivision_size), 0, floor(_point.z/spatial_subdivision_size))
	_point = Vector3( fmod(_point.x,spatial_subdivision_size), 0, fmod(_point.z,spatial_subdivision_size))
	var mat_pos = Vector3( floor(_point.x/dist.x), 0, floor(_point.z/dist.y))
	if grid_pos.x<0 or grid_pos.z<0:
		return {}
	if grid_pos.z>=matrix.size():
		grid_pos.z=matrix.size()-1
	if grid_pos.x>=matrix[0].size():
		grid_pos.x=matrix[0].size()-1
	while matrix[grid_pos.z][grid_pos.x].size()<=layer_index:
		matrix[grid_pos.z][grid_pos.x].append(null)
	var inst = matrix[grid_pos.z][grid_pos.x][layer_index]
	if inst==null:
		if use_layer_index<0:
			inst = generate_instance(layer_meshes[layer_index][0],layer_materials[layer_index][0])
		else:
			inst = generate_instance(layer_meshes[use_layer_index][0],layer_materials[layer_index][0])
		matrix[grid_pos.z][grid_pos.x][layer_index] = inst
		var _xx = grid_pos.x*spatial_subdivision_size+spatial_subdivision_size*0.5-aabb.size.x*0.5
		var _zz = grid_pos.z*spatial_subdivision_size+spatial_subdivision_size*0.5-aabb.size.z*0.5
		var d_offset = get_parent().get_aabb().pos + get_parent().get_aabb().size/2
		d_offset.y = 0
		inst.set_translation( Vector3(_xx,0,_zz) + d_offset )
	var index = mat_pos.z * ceil(spatial_subdivision_size/dist.y) + mat_pos.x
	var t = inst.get_multimesh().get_instance_transform(index)
	var res = {grid=grid_pos, mat=mat_pos, mesh=inst.get_multimesh(), index=index, trans=t, o_trans=inst.get_meta('_matrix')[index], instance=inst}
	return res

func generate_instance(static_mesh,base_material):
	var offset = Vector3(-spatial_subdivision_size/2,0,-spatial_subdivision_size/2)
	var final = Vector3(-offset.x,0,-offset.z)
	var mat = []
	var i = 0
	var z = offset.z
	var mesh = MultiMesh.new()
	var instance = MultiMeshInstance.new()
	mesh.set_mesh(static_mesh)
	instance.set_draw_range_begin( get_parent().get_draw_range_begin() )
	instance.set_draw_range_end( get_parent().get_draw_range_end() )
	instance.set_multimesh(mesh)
	if base_material:
		instance.set_material_override(base_material)
	mesh.set_instance_count( ceil(spatial_subdivision_size/dist.x) * ceil(spatial_subdivision_size/dist.y) )
	while z<final.z:
		var x = offset.x
		while x<final.x:
			var m = Matrix3().rotated(Vector3(0,1,0),rand_range(-PI,PI))
			var rx = rand_range(-dist.x/2,dist.x/2)
			var rz = rand_range(-dist.y/2,dist.y/2)
			var p = Vector3(x+rx,0,z+rz)
			var tr = Transform(m,p)
			mat.append(tr)
			mesh.set_instance_transform(i,Transform(Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0),p))
			i += 1
			x += dist.x
		z += dist.y
	mesh.set_aabb(get_parent().get_aabb())
	instance.set_meta('_matrix',mat)
	get_child(layer_index).add_child(instance)
	return instance

# initialize layer data matrix
func add_layer(static_mesh):
	var layer = Spatial.new() #layer container
	var aabb = get_parent().get_aabb()
	var aabb_size = aabb.size / spatial_subdivision_size
	layer_meshes.append([static_mesh])
	layer_materials.append([null])
	layer.set_meta('_mesh',static_mesh)
	layer.set_meta('_material',null)
	add_child(layer)
	
	# setupe meta-data of this layer
	layer.set_meta('_data',{meshes=[null],materials=[null],ranges=[[0,0]],randomization=1})
	layer.set_name(tr('Layer')+" "+str(get_child_count()-1))
	
	var g = GrassLayerData.new(layer)
	layer_panel.add_child(g)
	layer_index = get_child_count()-1
	get_layers_handlers()
	
	return layer

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

###
# This read a old source code and parse it on a new worker data
# to prevent issues the version control in beggining of script
# is used.
func convert_code_to_data(data):
	var ini = data.find('!grass_plugin ') + 14
	var version = data.substr( ini, data.find("\n") - ini)
	var int_version = int( version.substr(1,version.length()-1).replace('.','') )
	
	# no work in versions before 1.0.2
	if int_version<110:
		OS.alert( tr('This script can open grass from version 1.1.0 and later.\nCurrent version is ') + str(int_version), tr('Script Version Conflict'))
		return
	
	ini = data.find('var grass_step = ') + 17
	var step = float( data.substr(ini, data.find("\n",ini)-ini) )
	self.dist = Vector2(step,step)
	
	ini = data.find('var space_division_size = Vector3(')+34
	var space_division_size = int( data.substr(ini, data.find(",",ini)-ini) )
	self.spatial_subdivision_size = space_division_size
	
	# find mesh layer information
	var layers = []
	var mesh_paths = []
	var material_paths = []
	var fars = []
	var nears = []
	var layer_indexes = []
	var layer_counters = []
	
	ini = data.find('var mesh_layers_data = [')+25
	var limit = 10000
	var i = 0
	while true:
		var endline = data.find("\n",ini+1)
		var st = data.substr(ini,endline-ini)
		
		if st.find('	[')==0:
			layer_indexes.append(i)
			layer_counters.append(0)
		
		if st.find('{')>-1:
			ini = st.find("mesh='")+6
			var mesh = st.substr(ini,st.find("'",ini)-ini)
			ini = st.find("far=")+4
			var far = int(st.substr(ini,st.find(",",ini)-ini))
			ini = st.find("near=")+5
			var near = int(st.substr(ini,st.find(",",ini)-ini))
			ini = st.find("material_override='")+19
			var material_override = st.substr(ini,st.find("'",ini)-ini)
			mesh_paths.append(mesh)
			material_paths.append(material_override)
			fars.append(far)
			nears.append(nears)
			layer_counters[layer_counters.size()-1] += 1
			i += 1
		
		limit -= 1
		if st=="]" or limit<0:
			break
		ini = endline+1
	ini = data.find('# randomization = ',ini)+18
	var randomizers = []
	for rm in data.substr(ini,data.find(' ',ini)-ini).split(','):
		randomizers.append(float(rm))
	
	ini = data.find('var layer_names = [') + 19
	var layer_nomes = []
	for nm in data.substr(ini,data.find(']',ini)-ini).split(','):
		layer_nomes.append( nm.substr(1,nm.length()-2) )
	
	var binary_file_name = null
	ini = data.find('user://.grass_editor_only')
	if ini>-1:
		binary_file_name = data.substr(ini,data.find("\n",ini+1)-ini)
	
	# brute data
	var division_data = []
	var division_indexes = []
	ini = data.find('var data = [')+13
	limit = 100000
	var i = 0
	while true:
		var endline = data.find("\n",ini+1)
		var st = data.substr(ini,endline-ini)
		
		if st.find('	[')==0:
			division_indexes.append(i)
		
		if st.find('		[')==0:
			var l = st.substr(3,st.find(']')-3)
			division_data.append( l )
			i += 1
		
		limit -= 1
		if st=="]" or limit<0:
			break
		ini = endline+1
	
	# try to open the positions data file
	var binary = File.new()
	if binary_file_name!=null:
		binary.open(binary_file_name, File.READ)
	
	# store layer data
	var layers_metadata = []
	layer_meshes.clear()
	layer_materials.clear()
	for i in range(layer_indexes.size()):
		var index = layer_indexes[i]
		var mat = []
		var msh = []
		var rranges = []
		for i2 in range(layer_counters[i]):
			msh.append(mesh_paths[index+i2])
			if material_paths[index+i2].length()>0:
				mat.append(material_paths[i])
			else:
				mat.append(null)
			rranges.append( [RawArray(nears).get(index+i2),RawArray(fars).get(index+i2)] )
		layer_meshes.append(msh)
		layer_materials.append(mat)
		layers_metadata.append( {meshes=msh,materials=mat,ranges=rranges,randomization=randomizers[i]} )
		i += layer_counters[i]
			
	for i in range(layer_nomes.size()):
		var index = layer_indexes[i]
	
	# add real data
	for i in range(layer_nomes.size()):
		var mesh = ResourceLoader.load( layer_meshes[i][0], 'Mesh')
		var material = null
		if material_paths[i].length()>0:
			material = ResourceLoader.load( layer_materials[i][0],'Material')
		var far = fars[i]
		var near = nears[i]
		var layer = add_layer(mesh)
		layer.set_name(layer_nomes[i])
		#layer.set_meta('_data',{meshes=[null],materials=[null],ranges=[[0,0]],randomization=1})
		layer.set_meta('_data',layers_metadata[i])
		
		var size = get_parent().get_aabb().size
		var msize = get_parent().get_aabb().size/2
		msize.y = 0
		var start = get_parent().get_aabb().pos
		start.y = 0
		var division_index = division_indexes[i]
		var sps = Vector3(spatial_subdivision_size,0,spatial_subdivision_size)
		var divisao = 0
		var _grid_pos = Vector3(0,0,0)
		for mz in range(ceil(size.z/spatial_subdivision_size)):
			_grid_pos.x = 0
			for mx in range(ceil(size.x/spatial_subdivision_size)):
				var pos = start + sps*0.5 + Vector3(mx, 0, mz) * sps
				var rdata = division_data[divisao].split(',')
				divisao += 1
				var bin_size = 0
				if binary.is_open():
					bin_size = binary.get_32()
				if bin_size>0:
					layer_index = i
					var inst = generate_instance(mesh,material)
					var mat = []
					inst.set_translation(pos)
					matrix[_grid_pos.z][_grid_pos.x].append(inst)
					for ii in range(bin_size): #range(inst.get_multimesh().get_instance_count()):
						var tr = inst.get_multimesh().get_instance_transform(ii)
						var s = binary.get_float()
						var r = binary.get_float()
						var x = binary.get_float()
						var y = binary.get_float()
						var z = binary.get_float()
						inst.get_multimesh().set_instance_transform(ii,Transform( Matrix3().rotated(Vector3(0,1,0),r).scaled(Vector3(s,s,s)), Vector3(x,y,z)) )
						mat.append( Transform(Matrix3().rotated(Vector3(0,1,0),r), Vector3(x,y,z)) )
					inst.get_multimesh().generate_aabb()
					inst.set_meta('_matrix',mat)
				else:
					matrix[_grid_pos.z][_grid_pos.x].append(null)
				_grid_pos.x += 1
				
			_grid_pos.z += 1
		
	layer_index = 0
	

func _init(panel):
	self.layer_panel = panel

