extends Control

const sc := 1.0
const numInv := 4

var fov := PI/3.0

@onready var mainData := preload("res://scenes/main.tscn")
@onready var outputViewer := get_node("outTexture")
var main:Node2D

var rd : RenderingDevice
var shaderRID:RID

var wallDataRID:RID
var worldDataRID:RID
var outputRID:RID
var textureRID:RID

var uniformSetRID:RID
var pipelineRID:RID

var numRays:int
var texHeight:int

func _ready() -> void:
	calculateDim()
	
	main = mainData.instantiate()
	add_child(main)
	main.visible = false
	
	loadShader()
	
	var wallData:PackedByteArray = main.getWallData()
	createIOStream(wallData, main.getPlayerPos(), main.getPlayerDir())
	dispatchShader()

func _physics_process(delta) -> void:
	var wallData:PackedByteArray = main.getWallData()
	updateData(wallData, main.getPlayerPos(), main.getPlayerDir())
	
	var outputData := dispatchShader()
	main.ref.global_position = Vector2(outputData[0], outputData[1])

func loadShader() -> void:
	rd = RenderingServer.create_local_rendering_device()
	var shader_file := load("res://compute/computeShader.glsl")
	var shader_spirv:RDShaderSPIRV = shader_file.get_spirv()
	shaderRID = rd.shader_create_from_spirv(shader_spirv)

func createIOStream(wallDataBytes:PackedByteArray, pPos:Vector2, pDir:Vector2) -> void:
	wallDataRID = rd.storage_buffer_create(wallDataBytes.size(), wallDataBytes)
	
	var wdUniform := RDUniform.new()
	wdUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	wdUniform.binding = 0
	wdUniform.add_id(wallDataRID)
	
	var worldDataBytes := PackedFloat32Array([pPos.x, pPos.y, pDir.x, pDir.y, fov]).to_byte_array()
	worldDataRID = rd.storage_buffer_create(worldDataBytes.size(), worldDataBytes)
	
	var worldUniform := RDUniform.new()
	worldUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	worldUniform.binding = 1
	worldUniform.add_id(worldDataRID)
	
	var outputDataBytes := PackedFloat32Array([0.0, 0.0]).to_byte_array()
	outputRID = rd.storage_buffer_create(outputDataBytes.size(), outputDataBytes)
	
	var outUniform := RDUniform.new()
	outUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	outUniform.binding = 2
	outUniform.add_id(outputRID)
	
	var imageFormat := RDTextureFormat.new()
	imageFormat.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	imageFormat.width = numRays
	imageFormat.height = texHeight
	
	imageFormat.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var blankImg := Image.create(numRays, texHeight, false, Image.FORMAT_RGBA8)
	
	textureRID = rd.texture_create(imageFormat, RDTextureView.new(), [blankImg.get_data()])
	
	var texUniform := RDUniform.new()
	texUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	texUniform.binding = 3
	texUniform.add_id(textureRID)
	
	uniformSetRID = rd.uniform_set_create([wdUniform, worldUniform, outUniform, texUniform], shaderRID, 0)

func updateData(wallDataBytes:PackedByteArray, pPos:Vector2, pDir:Vector2) -> void:
	rd.buffer_update(wallDataRID, 0, wallDataBytes.size(), wallDataBytes)
	
	var worldDataBytes := PackedFloat32Array([pPos.x, pPos.y, pDir.x, pDir.y, fov]).to_byte_array()
	rd.buffer_update(worldDataRID, 0, worldDataBytes.size(), worldDataBytes)

func dispatchShader() -> PackedFloat32Array:
	pipelineRID = rd.compute_pipeline_create(shaderRID)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipelineRID)
	rd.compute_list_bind_uniform_set(compute_list, uniformSetRID, 0)
	rd.compute_list_dispatch(compute_list, numRays/numInv, texHeight/numInv, 1)
	rd.compute_list_end()
	
	rd.submit()
	rd.sync()
	
	var debugBytes := rd.buffer_get_data(outputRID)
	var debugOut := debugBytes.to_float32_array()
	
	var textureBytes := rd.texture_get_data(textureRID, 0)
	var texture := Image.create_from_data(numRays, texHeight, false, Image.FORMAT_RGBA8, textureBytes)

	outputViewer.texture = ImageTexture.create_from_image(texture)
	
	return debugOut


func updateFOV(newFov:float) -> void:
	fov = deg_to_rad(newFov)

func calculateDim() -> void:
	numRays = int(get_viewport_rect().size.x / sc)
	numRays = numRays - numRays%numInv
	texHeight = int(get_viewport_rect().size.y / sc)
	texHeight = texHeight - texHeight%numInv

#Cleanup -----------

func _notification(what) -> void:
	if what == NOTIFICATION_PREDELETE:
		cleanup_gpu()

func cleanup_gpu() -> void:
	if rd == null:
		return
	
	rd.free_rid(pipelineRID)
	pipelineRID = RID()
	
	rd.free_rid(uniformSetRID)
	uniformSetRID = RID()
	
	rd.free_rid(wallDataRID)
	wallDataRID = RID()
	
	rd.free_rid(worldDataRID)
	worldDataRID = RID()
	
	rd.free_rid(outputRID)
	outputRID = RID()
	
	rd.free_rid(shaderRID)
	shaderRID = RID()
	
	rd.free()
	rd = null
