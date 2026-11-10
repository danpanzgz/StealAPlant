--!strict
--[[
	ErrorMessages.lua
	Traduce los códigos de error del servidor ("not_enough_cash"...) a frases
	claras para el jugador. Un solo sitio: si sale un código nuevo, se añade aquí.
]]

local ErrorMessages = {}

local MESSAGES: { [string]: string } = {
	not_enough_cash = "💸 No tienes suficiente dinero",
	not_enough = "💸 No tienes suficiente",
	garden_full = "🌱 Tu jardín está lleno. Renace para tener más huecos",
	plant_capacity_reached = "🌼 No caben más flores colocadas. Renace para más espacio",
	missing_sacrifice = "🌿 Te falta la planta que hay que sacrificar",
	no_seed_in_inventory = "🌰 No te quedan semillas de esa planta",
	out_of_stock = "📦 Sin stock. Espera al próximo restock",
	stock_refreshed = "🔄 El stock cambió, vuelve a intentarlo",
	invalid_garden_position = "📍 Planta dentro del suelo marrón de TU jardín",
	invalid_position = "📍 Ese punto no es válido",
	position_occupied = "📍 Ahí ya hay algo. Elige un hueco libre",
	too_far_from_garden = "🚶 Acércate a tu jardín",
	too_far_from_plot = "🚶 Estás demasiado lejos",
	carrying_stolen_plant = "🕵️ Primero lleva la planta robada a tu jardín",
	plant_not_owned = "🌼 Esa planta ya no está en tu mochila",
	plant_is_placed = "🌼 Esa planta está colocada en el jardín",
	not_mature = "⏳ Aún está creciendo",
	not_ready = "⏳ Todavía no está listo",
	plant_not_ready = "⏳ Todavía no está lista",
	pack_not_owned = "🎁 No tienes ese pack",
	egg_not_owned = "🥚 No tienes ese huevo",
	gear_not_owned = "🧰 No tienes ese objeto",
	incubator_locked = "🔒 Desbloquea primero el incubador",
	already_unlocked = "✅ Ya lo tienes desbloqueado",
	already_claimed = "✅ Ya reclamado",
	level_locked = "🔒 Aún no has llegado a ese nivel",
	no_pass = "⭐ Necesitas el Pase de Temporada",
	max_level = "🏆 Ya está al nivel máximo",
	shield_cooldown = "🛡️ El domo se está recargando",
	rate_limited = "⏱️ Más despacio, inténtalo de nuevo",
	no_profile = "⏳ Tus datos aún se están cargando",
	profile_missing = "⏳ Tus datos aún se están cargando",
	player_not_found = "👤 No se encuentra a ese jugador",
	self_gift = "🎁 No puedes regalarte cosas a ti mismo",
	inventory_full = "🎒 Tienes la mochila llena",
	item_limit_reached = "🎒 Has llegado al límite de ese objeto",
	no_growing_crop_nearby = "🌱 No hay ningún cultivo creciendo cerca",
	no_free_slot = "🛡️ No te quedan huecos de defensa. Mejora el jardín",
	invalid_args = "⚠️ Acción no válida",
	garden_unavailable = "🏡 Tu jardín aún no está listo",
	too_many_traps = "🪤 Ya tienes 3 trampas activas",
	trap_outside_garden = "🪤 Colócala dentro de tu jardín",
	nothing_to_sell = "🧺 No tienes nada que vender aquí",
	use_seed_packs = "🎁 Abre los packs desde la mochila",
}

function ErrorMessages.Get(reason: any): string
	if type(reason) == "string" then
		local text = MESSAGES[reason]
		if text then
			return text
		end
		-- Texto ya legible (contiene espacios): se muestra tal cual.
		if string.find(reason, " ", 1, true) then
			return reason
		end
	end
	return "⚠️ No se pudo completar la acción"
end

return ErrorMessages
