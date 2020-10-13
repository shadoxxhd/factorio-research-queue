local eventlib = require('__flib__.event')
local guilib = require('__flib__.gui')
local translationlib = require('__flib__.translation')

local queue = require('.queue')
local util = require('.util')

local function update_queue(player)
  local player_data = global.players[player.index]
  local gui_data = player_data.gui

  queue.update(player)
  log('queue:')
  for tech in queue.iter(player) do
    log('\t'..tech.name)
  end

  gui_data.queue.clear()
  local is_head = true
  for tech in queue.iter(player) do
    guilib.build(gui_data.queue, {
      guilib.templates.tech_queue_item(player, tech, is_head),
    })
    is_head = false
  end
end

local function get_localised_string_key(player, localised_string)
  return translationlib.serialise_localised_string(localised_string)
end

local function start_translations(player)
  if translationlib.translating_players_count() > 0 then
    eventlib.on_tick(function(event)
      if translationlib.translating_players_count() > 0 then
        translationlib.iterate_batch(event)
      else
        eventlib.on_tick(nil)
      end
    end)
  end
end

local function get_translated_strings(player, localised_strings)
  local player_data = global.players[player.index]
  local translation_data = player_data.translations
  local translated_strings = {}
  local requests = {}
  for _, localised_string in ipairs(localised_strings) do
    local key = get_localised_string_key(player, localised_string)
    local translation_request = translation_data[key]
    if translation_request ~= nil then
      if translation_request.result ~= nil then
        table.insert(translated_strings, translation_request.result)
      end
    else
      translation_data[key] = {}
      table.insert(requests, {
        dictionary = 'search',
        internal = key,
        localised = localised_string,
      })
    end
  end
  if #requests > 0 then
    translationlib.add_requests(player.index, requests)
    start_translations(player)
  end
  return translated_strings
end

local function update_techs(player)
  local player_data = global.players[player.index]
  local gui_data = player_data.gui
  local filter_data = player_data.filter
  local tech_ingredients = player_data.tech_ingredients
  local force = player.force

  gui_data.tech_ingredient_filter_buttons.clear()
  for _, tech_ingredient in ipairs(tech_ingredients) do
    local enabled = filter_data.ingredients[tech_ingredient.name]
    guilib.build(gui_data.tech_ingredient_filter_buttons, {
      {
        name = 'tech_ingredient_filter_button.'..tech_ingredient.name,
        type = 'sprite-button',
        style =
          'rq_tech_ingredient_filter_button_' ..
            (enabled and 'enabled' or 'disabled'),
        handlers = 'tech_ingredient_filter_button',
        sprite = string.format('%s/%s', 'item', tech_ingredient.name),
        tooltip = {
          'sonaxaton-research-queue.tech-ingredient-filter-button-' ..
            (enabled and 'enabled' or 'disabled'),
          tech_ingredient.localised_name,
        },
      },
    })
  end

  gui_data.techs.clear()
  for _, tech in pairs(force.technologies) do
    local visible = (function()
      if not tech.enabled then
        return false
      end

      local ingredients_filter = filter_data.ingredients
      for _, ingredient in pairs(tech.research_unit_ingredients) do
        if not ingredients_filter[ingredient.name] then
          return false
        end
      end

      local search_terms = filter_data.search_terms
      local search_matches = (function()
        if #search_terms == 0 then
          return true
        end

        local localised_strings = {tech.localised_name, tech.localised_description}
        for _, effect in ipairs(tech.effects) do
          if effect.type == 'nothing' then
            table.insert(localised_strings, effect.effect_description)
          elseif effect.type == 'give-item' then
            local item = game.item_prototypes[effect.item]
            table.insert(localised_strings, item.localised_name)
            -- table.insert(localised_strings, item.localised_description)
          elseif effect.type == 'unlock-recipe' then
            local recipe = game.recipe_prototypes[effect.recipe]
            table.insert(localised_strings, recipe.localised_name)
            -- table.insert(localised_strings, recipe.localised_description)
          elseif effect.type == 'gun-speed' then
            local ammo_category = game.ammo_category_prototypes[effect.ammo_category]
            table.insert(localised_strings, ammo_category.localised_name)
            -- table.insert(localised_strings, ammo_category.localised_description)
          elseif effect.type == 'turret-attack' then
            local entity = game.entity_prototypes[effect.turret_id]
            table.insert(localised_strings, entity.localised_name)
            -- table.insert(localised_strings, entity.localised_description)
          else
            table.insert(localised_strings, {'modifier-description.'..effect.type, effect.modifier})
          end
        end

        local strings = get_translated_strings(player, localised_strings)

        if next(strings) == nil then
          -- nothing translated yet, just call it a match
          return true
        end

        for _, s in ipairs(strings) do
          if util.fuzzy_search(s, search_terms) then
            return true
          end
        end

        return false
      end)()
      if not search_matches then
        return false
      end

      return true
    end)()
    if visible then
      guilib.build(gui_data.techs, {
        guilib.templates.tech_list_item(player, tech),
      })
    end
  end
end

local function update_search(player)
  local player_data = global.players[player.index]
  local gui_data = player_data.gui
  local filter_data = player_data.filter

  local search_text = gui_data.search.text
  filter_data.search_terms = util.prepare_search_terms(search_text)
end

local function toggle_filter(player, item)
  local player_data = global.players[player.index]
  local gui_data = player_data.gui
  local filter_data = player_data.filter

  local enabled = filter_data.ingredients[item.name]
  enabled = not enabled
  filter_data.ingredients[item.name] = enabled
end

local function auto_select_tech_ingredients(player)
  local player_data = global.players[player.index]
  local filter_data = player_data.filter
  local tech_ingredients = player_data.tech_ingredients

  for _, tech_ingredient in ipairs(tech_ingredients) do
    filter_data.ingredients[tech_ingredient.name] = util.is_item_available(player, tech_ingredient.name)
  end
end

local function create_guis(player)
  local gui_data = guilib.build(player.gui.screen, {
    {
      save_as = 'window',
      type = 'frame',
      style = 'rq_main_window',
      handlers = 'window',
      direction = 'vertical',
      elem_mods = {
        visible = false,
      },
      children = {
        {
          save_as = 'titlebar',
          type = 'flow',
          children = {
            {
              template = 'frame_title',
              caption = {'sonaxaton-research-queue.window-title'},
            },
            {
              template = 'titlebar_drag_handle',
            },
            {
              template = 'frame_action_button',
              handlers = 'research_button',
              sprite = 'rq-enqueue-first-white',
            },
            {
              template = 'frame_action_button',
              handlers = 'refresh_button',
              sprite = 'rq-refresh',
            },
            {
              template = 'frame_action_button',
              handlers = 'close_button',
              sprite = 'utility/close_white',
              hovered_sprite = 'utility/close_black',
              clicked_sprite = 'utility/close_black',
            },
          },
        },
        {
          type = 'flow',
          style = 'horizontal_flow',
          style_mods = {
            horizontal_spacing = 12,
          },
          children = {
            {
              save_as = 'queue',
              type = 'scroll-pane',
              style = 'rq_tech_queue_list_box',
              vertical_scroll_policy = 'always',
            },
            {
              type = 'flow',
              style = 'vertical_flow',
              style_mods = {
                vertical_spacing = 8,
              },
              direction = 'vertical',
              children={
                -- TODO: hide search textfield in a button like tech GUI
                {
                  type = 'flow',
                  style = 'rq_tech_list_filter_container',
                  direction = 'horizontal',
                  children = {
                    {
                      type = 'scroll-pane',
                      style = 'rq_tech_ingredient_filter_buttons_scroll_box',
                      children = {
                        {
                          save_as = 'tech_ingredient_filter_buttons',
                          type = 'flow',
                          direction = 'horizontal',
                        },
                      },
                    },
                    {
                      save_as = 'search',
                      type = 'textfield',
                      handlers = 'search',
                      clear_and_focus_on_right_click = true,
                    },
                  },
                },
                {
                  type = 'scroll-pane',
                  style = 'rq_tech_list_list_box',
                  vertical_scroll_policy = 'always',
                  children = {
                    {
                      save_as = 'techs',
                      type = 'table',
                      style = 'rq_tech_list_table',
                      column_count = 5,
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
  })

  gui_data.window.force_auto_center()
  gui_data.titlebar.drag_target = gui_data.window

  local tech_ingredients = {}
  for _, item in pairs(game.get_filtered_item_prototypes{{filter='tool'}}) do
    local is_tech_ingredient = (function()
      for _, tech in pairs(player.force.technologies) do
        if tech.enabled then
          for _, ingredient in pairs(tech.research_unit_ingredients) do
            if ingredient.type == 'item' and ingredient.name == item.name then
              return true
            end
          end
        end
      end
      return false
    end)()
    if is_tech_ingredient then
      table.insert(tech_ingredients, item)
    end
  end
  table.sort(tech_ingredients, function(a, b) return a.order < b.order end)

  local filter_data = {
    search_terms = {},
    ingredients = {},
  }

  local player_data = global.players[player.index]
  player_data.gui = gui_data
  player_data.filter = filter_data
  player_data.tech_ingredients = tech_ingredients
  player_data.translations = {}

  auto_select_tech_ingredients(player)
  update_queue(player)
  update_techs(player)
end

local function destroy_guis(player)
  local player_data = global.players[player.index]
  local gui_data = player_data.gui

  gui_data.window.destroy()

  player_data.gui = nil
  player_data.filter = nil
  player_data.translations = nil
end

local function open(player)
  local player_data = global.players[player.index]
  local gui_data = player_data.gui

  player_data.tech_gui_open = nil
  gui_data.window.visible = true
  player.opened = gui_data.window
  player.set_shortcut_toggled('sonaxaton-research-queue', true)

  gui_data.search.focus()
  gui_data.search.select_all()

  update_search(player)
  update_queue(player)
  update_techs(player)
end

local function close(player)
  local player_data = global.players[player.index]
  local gui_data = player_data.gui

  gui_data.window.visible = false
  if player.opened == gui_data.window then
    player.opened = nil
  end
  player.set_shortcut_toggled('sonaxaton-research-queue', false)
end

local function on_research_finished(player, tech)
  local player_data = global.players[player.index]
  local filter_data = player_data.filter
  local tech_ingredients = player_data.tech_ingredients

  for _, tech_ingredient in ipairs(tech_ingredients) do
    local newly_available = (function()
      for _, effect in pairs(tech.effects) do
        if effect.type == 'unlock-recipe' then
          local recipe = game.recipe_prototypes[effect.recipe]
          for _, product in pairs(recipe.products) do
            if product.type == 'item' and product.name == tech_ingredient.name then
              return true
            end
          end
        end
      end
      return false
    end)()
    if newly_available then
      filter_data.ingredients[tech_ingredient.name] = true
    end
  end

  update_queue(player)
  update_techs(player)
end

local function on_string_translated(player, event)
  if event.translated then
    local player_data = global.players[player.index]
    local translation_data = player_data.translations

    local sort_data, finished = translationlib.process_result(event)

    if sort_data then
      local player_data = global.players[player.index]
      local translation_data = player_data.translations

      if sort_data.search ~= nil then
        for _, key in ipairs(sort_data.search) do
          local result = event.result
          if translation_data[key] == nil then
            translation_data[key] = {}
          end
          translation_data[key].result = result
        end
      end

      if finished then
        update_techs(player)
      end
    end
  end
end

guilib.add_templates{
  frame_action_button = {
    type = 'sprite-button',
    style = 'frame_action_button',
    mouse_button_filter = {'left'},
  },
  tool_button = {
    type = 'sprite-button',
    style = 'tool_button',
    mouse_button_filter = {'left'},
  },
  frame_title = {
    type = 'label',
    style = 'frame_title',
    elem_mods = {
      ignored_by_interaction = true,
    },
  },
  titlebar_drag_handle = {
    type = 'empty-widget',
    style = 'flib_titlebar_drag_handle',
    elem_mods = {
      ignored_by_interaction = true,
    },
  },
  tech_button = function(tech, style)
    local cost =
      '(' ..
      '[img=quantity-time]' ..
      (tech.research_unit_energy / 60) ..
      's'
    for _, ingredient in ipairs(tech.research_unit_ingredients) do
      cost = cost .. string.format(' [img=%s/%s]%d',
        ingredient.type,
        ingredient.name,
        ingredient.amount)
    end
    cost = cost ..
      ') × ' ..
      tostring(tech.research_unit_count)
    return {
      name = 'tech_button.'..tech.name,
      type = 'sprite-button',
      style = style,
      handlers = 'tech_button',
      sprite = 'technology/'..tech.name,
      tooltip = {'', tech.localised_name, '\n', cost},
      number = string.match(tech.name, '-%d+$') and tech.level or nil,
    }
  end,
  tech_queue_item = function(player, tech, is_head)
    -- TODO: show ETC
    return
      {
        type = 'frame',
        style = 'rq_tech_queue_item',
        children = {
          guilib.templates.tech_button(
            tech,
            'rq_tech_queue'..(is_head and '_head' or '')..'_item_tech_button'),
          {
            type = 'empty-widget',
            style = 'flib_horizontal_pusher',
          },
          {
            type = 'flow',
            direction = 'vertical',
            style = 'rq_tech_queue_item_buttons',
            children = {
              {
                name = 'shift_up_button.'..tech.name,
                type = 'button',
                style = 'rq_tech_queue_item_shift_up_button',
                handlers = 'shift_up_button',
                tooltip = {'sonaxaton-research-queue.shift-up-button-tooltip', tech.localised_name},
                visible = queue.can_shift_earlier(player, tech),
              },
              {
                type = 'empty-widget',
                style = 'flib_vertical_pusher',
              },
              {
                name = 'dequeue_button.'..tech.name,
                template = 'tool_button',
                style = 'rq_tech_queue_item_close_button',
                handlers = 'dequeue_button',
                sprite = 'utility/close_black',
                tooltip = {'sonaxaton-research-queue.dequeue-button-tooltip', tech.localised_name},
              },
              {
                type = 'empty-widget',
                style = 'flib_vertical_pusher',
              },
              {
                name = 'shift_down_button.'..tech.name,
                type = 'button',
                style = 'rq_tech_queue_item_shift_down_button',
                handlers = 'shift_down_button',
                tooltip = {'sonaxaton-research-queue.shift-down-button-tooltip', tech.localised_name},
                visible = queue.can_shift_later(player, tech),
              },
            },
          },
        },
      }
  end,
  tech_list_item = function(player, tech)
    -- TODO: option to hide researched techs
    local researchable = queue.is_researchable(player, tech)
    local queued = queue.in_queue(player, tech)
    local researched = tech.researched
    local style_prefix =
      'rq_tech_list_item' ..
        ((queued and '_queued') or
          (researched and '_researched') or '')
    return
      {
        type = 'flow',
        style = 'rq_tech_list_item',
        direction = 'vertical',
        children = {
          guilib.templates.tech_button(tech, style_prefix..'_tech_button'),
          {
            type = 'frame',
            style = style_prefix..'_tool_bar',
            direction = 'horizontal',
            children = {
              {
                name = 'enqueue_last_button.'..tech.name,
                template = 'tool_button',
                style = 'rq_tech_list_item_tool_button',
                handlers = 'enqueue_last_button',
                sprite = 'rq-enqueue-last-black',
                tooltip = {'sonaxaton-research-queue.enqueue-last-button-tooltip', tech.localised_name},
                enabled = researchable,
              },
              {
                name = 'enqueue_second_button.'..tech.name,
                template = 'tool_button',
                style = 'rq_tech_list_item_tool_button',
                handlers = 'enqueue_second_button',
                sprite = 'rq-enqueue-second-black',
                tooltip = {'sonaxaton-research-queue.enqueue-second-button-tooltip', tech.localised_name},
                enabled = researchable,
              },
              {
                name = 'enqueue_first_button.'..tech.name,
                template = 'tool_button',
                style = 'rq_tech_list_item_tool_button',
                handlers = 'enqueue_first_button',
                sprite = 'rq-enqueue-first-black',
                tooltip = {'sonaxaton-research-queue.enqueue-first-button-tooltip', tech.localised_name},
                enabled = researchable,
              },
            },
          },
        },
      }
  end,
}

guilib.add_handlers{
  window = {
    on_gui_closed = function(event)
      local player = game.players[event.player_index]
      if not global.players[player.index].tech_gui_open then
        close(player)
      end
    end,
  },
  close_button = {
    on_gui_click = function(event)
      local player = game.players[event.player_index]
      close(player)
    end,
  },
  refresh_button = {
    on_gui_click = function(event)
      log('refresh_button')
      local player = game.players[event.player_index]
      update_search(player)
      update_queue(player)
      update_techs(player)
    end,
  },
  research_button = {
    on_gui_click = function(event)
      log('research_button')
      local player = game.players[event.player_index]
      if player.force.current_research ~= nil then
        player.force.research_progress = 1
      end
    end,
  },
  tech_ingredient_filter_button = {
    on_gui_click = function(event)
      log('tech_ingredient_filter_button')
      local player = game.players[event.player_index]
      local _, _, item_name = string.find(event.element.name, '^tech_ingredient_filter_button%.(.+)$')
      local item = game.item_prototypes[item_name]
      toggle_filter(player, item)
      update_techs(player)
    end,
  },
  search = {
    on_gui_text_changed = function(event)
      log('search')
      local player = game.players[event.player_index]
      update_search(player)
      update_techs(player)
    end,
  },
  tech_button = {
    on_gui_click = function(event)
      local player = game.players[event.player_index]
      local _, _, tech_name = string.find(event.element.name, '^tech_button%.(.+)$')
      local force = player.force
      local tech = force.technologies[tech_name]
      if event.button == defines.mouse_button_type.left then
        global.players[player.index].tech_gui_open = true
        player.open_technology_gui(tech.name)
      elseif event.button == defines.mouse_button_type.right then
        queue.dequeue(player, tech)
        update_queue(player)
        update_techs(player)
      end
    end,
  },
  enqueue_last_button = {
    on_gui_click = function(event)
      log('enqueue_last_button')
      local player = game.players[event.player_index]
      local _, _, tech_name = string.find(event.element.name, '^enqueue_last_button%.(.+)$')
      local force = player.force
      local tech = force.technologies[tech_name]
      log('enqueue last '..tech.name)
      queue.enqueue_tail(player, tech)
      update_queue(player)
      update_techs(player)
    end,
  },
  enqueue_second_button = {
    on_gui_click = function(event)
      log('enqueue_second_button')
      local player = game.players[event.player_index]
      local _, _, tech_name = string.find(event.element.name, '^enqueue_second_button%.(.+)$')
      local force = player.force
      local tech = force.technologies[tech_name]
      log('enqueue second '..tech.name)
      queue.enqueue_before_head(player, tech)
      update_queue(player)
      update_techs(player)
    end,
  },
  enqueue_first_button = {
    on_gui_click = function(event)
      log('enqueue_first_button')
      local player = game.players[event.player_index]
      local _, _, tech_name = string.find(event.element.name, '^enqueue_first_button%.(.+)$')
      local force = player.force
      local tech = force.technologies[tech_name]
      log('enqueue first '..tech.name)
      queue.enqueue_head(player, tech)
      update_queue(player)
      update_techs(player)
    end,
  },
  shift_up_button = {
    on_gui_click = function(event)
      log('shift_up_button')
      local player = game.players[event.player_index]
      local _, _, tech_name = string.find(event.element.name, '^shift_up_button%.(.+)$')
      local force = player.force
      local tech = force.technologies[tech_name]
      log('shift earlier '..tech.name)
      queue[event.shift and 'shift_earliest' or 'shift_earlier'](player, tech)
      update_queue(player)
    end,
  },
  shift_down_button = {
    on_gui_click = function(event)
      log('shift_down_button')
      local player = game.players[event.player_index]
      local _, _, tech_name = string.find(event.element.name, '^shift_down_button%.(.+)$')
      local force = player.force
      local tech = force.technologies[tech_name]
      log('shift later '..tech.name)
      queue[event.shift and 'shift_latest' or 'shift_later'](player, tech)
      update_queue(player)
    end,
  },
  dequeue_button = {
    on_gui_click = function(event)
      log('dequeue_button')
      local player = game.players[event.player_index]
      local _, _, tech_name = string.find(event.element.name, '^dequeue_button%.(.+)$')
      local force = player.force
      local tech = force.technologies[tech_name]
      log('dequeue '..tech.name)
      queue.dequeue(player, tech)
      update_queue(player)
      update_techs(player)
    end,
  },
}

return {
  create_guis = create_guis,
  destroy_guis = destroy_guis,
  on_research_finished = on_research_finished,
  on_string_translated = on_string_translated,
  open = open,
  close = close,
}
