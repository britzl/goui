local M = {}

M.ANCHOR_NONE = 0
M.ANCHOR_LEFT = 1
M.ANCHOR_RIGHT = 2
M.ANCHOR_TOP = 3
M.ANCHOR_BOTTOM = 4

M.PIVOT_CENTER = vmath.vector3(0, 0, 0)
M.PIVOT_N = vmath.vector3(0, 1, 0)
M.PIVOT_NE = vmath.vector3(1, 1, 0)
M.PIVOT_E = vmath.vector3(1, 0, 0)
M.PIVOT_SE = vmath.vector3(1, -1, 0)
M.PIVOT_S = vmath.vector3(0, -1, 0)
M.PIVOT_SW = vmath.vector3(-1, -1, 0)
M.PIVOT_W = vmath.vector3(-1, 0, 0)
M.PIVOT_NW = vmath.vector3(-1, 1, 0)

M.ADJUST_MODE_FIT = 0
M.ADJUST_MODE_ZOOM = 1
M.ADJUST_MODE_STRETCH = 2

local projection = vmath.matrix4()
local view = vmath.matrix4()

local boxfactory = nil
local textfactory = nil

local nodes = {}

local function lookup_node(id)
	return nodes[id]
end

local function lookup_or_create_node(id)
	if not nodes[id] then
		nodes[id] = {
			enabled = true,
			visible = true,
			adjust_mode = M.ADJUST_MODE_FIT
		}
	end
	return nodes[id]
end

local DISPLAY_WIDTH = sys.get_config_int("display.width")
local DISPLAY_HEIGHT = sys.get_config_int("display.height")

local function screen_to_world(x, y, z, camera)
	--local projection = go.get(camera, "projection")
	--local view = go.get(camera, "view")
	local w, h = window.get_size()
	-- The window.get_size() function will return the scaled window size,
	-- ie taking into account display scaling (Retina screens on macOS for
	-- instance). We need to adjust for display scaling in our calculation.
	w = w / (w / DISPLAY_WIDTH)
	h = h / (h / DISPLAY_HEIGHT)

	-- https://defold.com/manuals/camera/#converting-mouse-to-world-coordinates
	local inv = vmath.inv(projection * view)
	x = (2 * x / w) - 1
	y = (2 * y / h) - 1
	z = (2 * z) - 1
	local x1 = x * inv.m00 + y * inv.m01 + z * inv.m02 + inv.m03
	local y1 = x * inv.m10 + y * inv.m11 + z * inv.m12 + inv.m13
	local z1 = x * inv.m20 + y * inv.m21 + z * inv.m22 + inv.m23
	return x1, y1, z1
end

function M.init()
	local url = msg.url()
	boxfactory = msg.url(url.socket, url.path, "boxfactory")
	textfactory = msg.url(url.socket, url.path, "textfactory")
end

function M.set_projection(p)
	projection = p
end

function M.set_view(v)
	view = v
end

function M.get_position(id)
	return go.get_position(id)
end

function M.get_rotation(id)
	return go.get_position(id)
end

function M.get_scale(id)
	return go.get_scale(id)
end

function M.get_parent(id)
	return go.get_parent(id)
end

function M.set_position(id, position)
	go.set_position(position, id)
end

function M.set_rotation(id, rotation)
	go.set_rotation(rotation, id)
end

function M.set_scale(id, scale)
	go.set_scale(scale, id)
end

function M.set_parent(id, parent_id, keep_world_transform)
	go.set_parent(id, parent_id, { keep_world_transform = keep_world_transform })
end

function M.get_id(id)
	return go.get_id(id)
end

function M.animate(id, property, playback, to, easing, duration, delay, complete_function)
	go.animate(id, property, playback, to, easing, duration, delay, complete_function)
end

function M.get_material(id)
	return go.get(id, "material")
end

function M.set_material(id, value)
	local node = lookup_or_create_node(id)
	if not node.original_material then
		node.original_material = go.get(id, "material")
	end
	go.set(id, "material", value)
end

function M.reset_material(id)
	local node = lookup_node(id)
	if node.original_material then
		go.set(id, "material", node.original_material)
	end
end

function M.get_font(id)
	return go.get(id, "font")
end

function M.get_font_resource(id)
	return go.get(id, "font")
end

function M.set_font(id, font)
	go.set(id, "font", font)
end

function M.get_xanchor(id)
	local node = lookup_node(id)
	return node and node.xanchor or M.ANCHOR_NONE
end

function M.set_xanchor(id, anchor)
	local node = lookup_or_create_node(id)
	node.xanchor = anchor
end

function M.get_yanchor(id)
	local node = lookup_node(id)
	return node and node.yanchor or M.ANCHOR_NONE
end

function M.set_yanchor(id, anchor)
	local node = lookup_or_create_node(id)
	node.yanchor = anchor
end

function M.get_pivot(id)
	local node = lookup_node(id)
	return node and node.pivot or M.PIVOT_CENTER
end

function M.set_pivot(id, pivot)
	local pos = go.get_position(id)
	local size = go.get(id, "size") * 0.5
	local node = lookup_or_create_node(id)
	if node.pivot then
		pos.x = pos.x - size.x * node.pivot.x
		pos.y = pos.y - size.y * node.pivot.y
	end
	pos.x = pos.x + size.x * pivot.x
	pos.y = pos.y + size.y * pivot.y
	node.pivot = pivot
	go.set_position(pos, id)
end

function M.pick_node(id, x, y)
	local node = lookup_or_create_node(id)
	if not node.enabled or not node.visible then
		return false
	end
	local pos = go.get_world_position(id)
	local size = go.get(id, "size") * 0.5
	return x > (pos.x - size.x)
		and x < (pos.x + size.x)
		and y > (pos.y - size.y)
		and y < (pos.y + size.y)
end

function M.is_enabled(id)
	local node = lookup_or_create_node(id)
	if node.enabled == nil then
		return true
	end
	return node.enabled
end

function M.set_enabled(id, enabled)
	local node = lookup_or_create_node(id)
	node.enabled = enabled
	msg.post(id, enabled and "enable" or "disable")
end

function M.get_visible(id)
	local node = lookup_or_create_node(id)
	return node.visible
end

function M.set_visible(id, visible)
	local node = lookup_or_create_node(id)
	node.visible = visible
	msg.post(id, visible and "enable" or "disable")
end

function M.get_adjust_mode(id)
end

function M.set_adjust_mode(id)
	local node = lookup_or_create_node(id)
end


function M.move_above(id, reference)
	local pos = go.get_position(reference)
	pos.z = pos.z + 0.0001
	go.set_position(pos, id)
end

function M.move_below(id, reference)
	local pos = go.get_position(reference)
	pos.z = pos.z - 0.0001
	go.set_position(pos, id)
end


function M.get_tree(id)
end

function M.show_keyboard(id)
end

function M.hide_keyboard(id)
end

function M.reset_keyboard(id)
end

function M.get_screen_position(id)
end

function M.set_screen_position(id)
end

function M.screen_to_local(id)
end

function M.reset_nodes(id)
end

function M.set_render_order(id) error("set_render_order is not supported") end
function M.set_fill_angle(id) error("set_fill_angle is not supported") end
function M.get_fill_angle(id) error("get_fill_angle is not supported") end
function M.set_perimeter_vertices(id) error("set_perimeter_vertices is not supported") end
function M.get_perimeter_vertices(id) error("get_perimeter_vertices is not supported") end
function M.set_inner_radius(id) error("set_inner_radius is not supported") end
function M.get_inner_radius(id) error("get_inner_radius is not supported") end
function M.set_outer_bounds(id) error("set_outer_bounds is not supported") end
function M.get_outer_bounds(id) error("get_outer_bounds is not supported") end
function M.new_pie_node(id) error("new_pie_node not supported") end

function M.set_leading(id, value)
	go.set(id, "leading", value)
end

function M.get_leading(id)
	return go.get(id, "leading")
end

function M.set_tracking(id, value)
	go.set(id, "tracking", value)
end

function M.get_tracking(id)
	return go.get(id, "tracking")
end

function M.set_size(id, value)
	go.set(id, "size", value)
end

function M.get_size(id)
	return go.get(id, "tracking")
end


function M.get_texture(id)
	return go.get(id, "image")
end

function M.set_texture(id, value)
	go.set(id, "image", value)
end

function M.get_flipbook(id)
	return go.get(id, "animation")
end

function M.play_flipbook(id, animation, complete_function, play_properties)
	sprite.play_flipbook(id, animation, complete_function, play_properties or {})
end


function M.new_texture(id)
end

function M.delete_texture(id)
end

function M.get_outline(id)
	return go.get(id, "outline")
end

function M.set_outline(id, value)
	go.set(id, "outline", value)
end

function M.get_shadow(id)
	return go.get(id, "shadow")
end

function M.set_shadow(id, value)
	go.set(id, "shadow", value)
end

function M.get_width(id)
	local size = go.get(id, "size")
	return size.x
end

function M.get_height(id)
	local size = go.get(id, "size")
	return size.y
end

function M.get_line_break(id)
	return go.get(id, "line_break")
end

function M.set_line_break(id)
	go.set(id, "line_break", value)
end

function M.set_text(id, text)
	label.set_text(id, text)
end

function M.get_text(id)
	return label.get_text(id)
end

function M.new_text_node(pos, text)
	if not textfactory then
		error("no text factory set, did you call oui.init()?")
	end
	local id = factory.create(textfactory, pos)
	local url = msg.url(nil, id, "label")
	label.set_text(url, text)
	return url
end

function M.new_box_node(pos, size)
	if not boxfactory then
		error("no box factory set, did you call oui.init()?")
	end
	local id = factory.create(boxfactory)
	local url = msg.url(nil, id, "sprite")
	go.set_position(pos, id)
	go.set(url, "size", size)
	return url
end

function M.cancel_animation(id, property)
	go.cancel_animations(id, property)
end

function M.delete_node(id)
	go.delete(id)
end

function M.get_flipbook_cursor(id)
	return go.get(id, "cursor")
end

function M.set_flipbook_cursor(id, value)
	go.set(id, "cursor", value)
end

function M.get_flipbook_playback_rate(id)
	return go.get(id, "playback_rate")
end

function M.set_flipbook_playback_rate(id, value)
	go.set(id, "playback_rate", value)
end

function M.set_color(id, color)
	local ok, tint = pcall(go.get, id, "tint")
	if ok then
		go.set(id, "tint", color)
		return
	end
	return go.set(id, "color", color)
end

function M.get_color(id)
	local ok, tint = pcall(go.get, id, "tint")
	if ok then
		return tint
	end
	return go.get(id, "color")
end

function M.new_particlefx_node(id)
end

function M.set_particlefx(id)
end

function M.get_particlefx(id)
end

function M.get_alpha(id)
	local ok, tint = pcall(go.get, id, "tint")
	if ok then
		return tint.w
	end
	local color = go.get(id, "color")
	return color.w
end

function M.set_alpha(id, value)
	local ok, tint = pcall(go.get, id, "tint.w")
	if ok then
		go.set(id, "tint.w", value)
		return
	end
	go.set(id, "color.w", value)
end


function M.get_blend_mode(id) error("get_blend_mode is not supported") end
function M.set_blend_mode(id) error("set_blend_mode is not supported") end
function M.get_clipping_mode(id) error("get_clipping_mode is not supported") end
function M.set_clipping_mode(id) error("set_clipping_mode is not supported") end
function M.get_clipping_visible(id) error("get_clipping_visible is not supported") end
function M.set_clipping_visible(id) error("set_clipping_visible is not supported") end
function M.get_clipping_inverted(id) error("get_clipping_inverted is not supported") end
function M.set_clipping_inverted(id) error("set_clipping_inverted is not supported") end
function M.get_index(id) error("get_index is not supported") end
function M.set_id(id) error("set_id is not supported") end
function M.get_node(id) error("get_node is not supported") end
function M.play_particlefx(id) error("play_particlefx is not supported, use particlefx.play() instead") end
function M.stop_particlefx(id) error("stop_particlefx is not supported, use particlefx.stop() instead") end
function M.set_inherit_alpha(id) error("set_inherit_alpha is not supported") end
function M.get_inherit_alpha(id) error("get_inherit_alpha is not supported") end
function M.set_texture_data(id) error("set_texture_data is not supported, use resource.create_texture() instead") end
function M.get_layer(id) error("get_layer is not supported") end
function M.set_layer(id) error("get_layer is not supported") end
function M.get_layout(id) error("get_layer is not supported") end
function M.get_slice9(id) error("get_slice9 is not supported") end
function M.set_slice9(id) error("set_slice9 is not supported") end
function M.cancel_flipbook(id) error("cancel_flipbook is not supported") end
function M.get_size_mode(id) error("get_size_mode is not supported") end
function M.set_size_mode(id) error("set_size_mode is not supported") end
function M.clone(id) error("clone is not supported, use factory.create instead") end
function M.clone_tree(id) error("clone_tree is not supported, use collectionfactory.create instead") end

return M