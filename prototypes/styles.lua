local util = require('util')

local styles = data.raw['gui-style'].default

local tech_list_tech_button_size = 64+8*2+8
local tech_queue_tech_button_size = 64*3/4+8

local function tech_graphical_set(type, opts)
  local highlighted = opts.highlighted
  local y = ({
    available = 136,
    conditionally_available = 153,
    unavailable = 170,
    researched = 187,
    disabled = 204,
  })[opts.style]
  local tint = opts.tint

  if type == 'button' then
    local default_graphical_set = {
      base = {
        position = {highlighted and 330 or 296, y},
        corner_size = 8,
        tint = tint,
      },
      shadow = default_shadow,
    }
    local other_graphical_set = {
      base = {
        position = {312, y},
        corner_size = 8,
        tint = tint,
      },
      shadow = default_shadow,
    }
    return {
      default_graphical_set = default_graphical_set,
      hovered_graphical_set = other_graphical_set,
      clicked_graphical_set = other_graphical_set,
      selected_graphical_set = other_graphical_set,
      selected_hovered_graphical_set = other_graphical_set,
      selected_clicked_graphical_set = other_graphical_set,
    }
  elseif type == 'ingredients' then
    return {
      base = {
        position = {highlighted and 364 or 347, y},
        corner_size = 8,
        tint = tint,
      },
      shadow = default_shadow,
    }
  elseif type == 'level' then
    return {
      base = {
        position = {397, y},
        corner_size = 8,
        tint = tint,
      },
      shadow = default_shadow,
    }
  end
end

styles.rq_main_window = {
  type = 'frame_style',
  parent = 'inner_frame_in_outer_frame',
  height = 500,
}

styles.rq_settings_window = {
  type = 'frame_style',
  parent = 'inner_frame_in_outer_frame',
  height = 500,
}

styles.rq_list_box = {
  type = 'scroll_pane_style',
  vertically_stretchable = 'on',
  extra_padding_when_activated = 0,
  graphical_set = {
    base = {position = {34, 0}, corner_size = 8},
    shadow = default_inner_shadow,
  },
}

styles.rq_tech_queue_head_frame = {
  type = 'frame_style',
  width = 4+6+tech_queue_tech_button_size+8+16+6+4,
  height = 4+6+tech_queue_tech_button_size+6+4,
  margin = 0,
  padding = 0,
  graphical_set = {
    base = {position = {34, 0}, corner_size = 8},
    shadow = default_inner_shadow,
  },
  background_graphical_set = {
    position = {282, 17},
    corner_size = 8,
    overall_tiling_horizontal_size = 6+tech_queue_tech_button_size+8+16+6,
    overall_tiling_horizontal_padding = 4,
    overall_tiling_horizontal_spacing = 16,
    overall_tiling_vertical_size = 6+tech_queue_tech_button_size+6,
    overall_tiling_vertical_padding = 4,
    overall_tiling_vertical_spacing = 4,
  },
}

styles.rq_tech_queue_list_box = {
  type = 'scroll_pane_style',
  parent = 'rq_list_box',
  width = 4+6+tech_queue_tech_button_size+8+16+6+4+12,
  background_graphical_set = {
    position = {282, 17},
    corner_size = 8,
    overall_tiling_horizontal_size = 6+tech_queue_tech_button_size+8+16+6,
    overall_tiling_vertical_size = 6+tech_queue_tech_button_size+6,
    overall_tiling_vertical_spacing = 4,
  },
}

styles.rq_tech_list_list_box = {
  type = 'scroll_pane_style',
  parent = 'rq_list_box',
  width = 4+5*tech_list_tech_button_size+4+12,
  background_graphical_set = {
    position = {282, 17},
    corner_size = 8,
    overall_tiling_horizontal_size = tech_list_tech_button_size-8,
    overall_tiling_horizontal_padding = 8/2,
    overall_tiling_horizontal_spacing = 8,
    overall_tiling_vertical_size = tech_list_tech_button_size+4+16+4+40-8,
    overall_tiling_vertical_padding = 8/2,
    overall_tiling_vertical_spacing = 8,
  },
}

styles.rq_tech_ingredient_filter_table_scroll_box = {
  type = 'scroll_pane_style',
}

styles.rq_tech_list_search_container = {
  type = 'horizontal_flow_style',
  horizontal_align = 'right',
  horizontally_stretchable = 'on',
  vertical_align = 'center',
}

styles.rq_filter_researched_button_enabled = {
  type = 'button_style',
  parent = 'green_slot',
  size = 28,
  padding = 2,
}

styles.rq_filter_researched_button_disabled = {
  type = 'button_style',
  parent = 'slot',
  size = 28,
  padding = 2,
}

styles.rq_tech_ingredient_filter_button_enabled = {
  type = 'button_style',
  parent = 'green_slot',
}

styles.rq_tech_ingredient_filter_button_disabled = {
  type = 'button_style',
  parent = 'slot',
}

styles.rq_tech_list_table = {
  type = 'table_style',
  horizontally_stretchable = 'off',
  horizontal_spacing = 0,
  vertical_spacing = 0,
}

styles.rq_tech_list_item = {
  type = 'vertical_flow_style',
  vertical_spacing = 0,
}

local tech_list_item_available = {style='available'}
local tech_list_item_unavailable = {style='unavailable'}
local tech_list_item_queued = {style='conditionally_available'}
local tech_list_item_queued_head = {style='conditionally_available', highlighted=true}
local tech_list_item_researched = {style='researched'}

styles.rq_tech_list_item_available_tech_button = util.merge{
  {
    type = 'button_style',
    size = tech_list_tech_button_size,
  },
  tech_graphical_set('button', tech_list_item_available),
}

styles.rq_tech_list_item_unavailable_tech_button = util.merge{
  {
    type = 'button_style',
    size = tech_list_tech_button_size,
  },
  tech_graphical_set('button', tech_list_item_unavailable),
}

styles.rq_tech_list_item_queued_tech_button = util.merge{
  {
    type = 'button_style',
    size = tech_list_tech_button_size,
  },
  tech_graphical_set('button', tech_list_item_queued),
}

styles.rq_tech_list_item_queued_head_tech_button = util.merge{
  {
    type = 'button_style',
    size = tech_list_tech_button_size,
  },
  tech_graphical_set('button', tech_list_item_queued_head),
}

styles.rq_tech_list_item_researched_tech_button = util.merge{
  {
    type = 'button_style',
    size = tech_list_tech_button_size,
  },
  tech_graphical_set('button', tech_list_item_researched),
}

styles.rq_tech_list_item_available_ingredients_bar = {
  type = 'frame_style',
  padding = 0,
  horizontal_flow_style = {
    type = 'horizontal_flow_style',
    horizontally_stretchable = 'on',
    horizontal_align = 'left',
  },
  graphical_set = tech_graphical_set('level', tech_list_item_available),
}

styles.rq_tech_list_item_unavailable_ingredients_bar = {
  type = 'frame_style',
  parent = 'rq_tech_list_item_available_ingredients_bar',
  graphical_set = tech_graphical_set('level', tech_list_item_unavailable),
}

styles.rq_tech_list_item_queued_ingredients_bar = {
  type = 'frame_style',
  parent = 'rq_tech_list_item_available_ingredients_bar',
  graphical_set = tech_graphical_set('level', tech_list_item_queued),
}

styles.rq_tech_list_item_queued_head_ingredients_bar = {
  type = 'frame_style',
  parent = 'rq_tech_list_item_available_ingredients_bar',
  graphical_set = tech_graphical_set('level', tech_list_item_queued_head),
}

styles.rq_tech_list_item_researched_ingredients_bar = {
  type = 'frame_style',
  parent = 'rq_tech_list_item_available_ingredients_bar',
  graphical_set = tech_graphical_set('level', tech_list_item_researched),
}

styles.rq_tech_list_item_ingredient = {
  type = 'image_style',
  width = 16,
  height = 16,
  stretch_image_to_widget_size = true,
}

styles.rq_tech_list_item_available_tool_bar = {
  type = 'frame_style',
  padding = 0,
  top_padding = 4,
  bottom_padding = 4,
  horizontal_flow_style = {
    type = 'horizontal_flow_style',
    horizontally_stretchable = 'on',
    horizontal_align = 'center',
  },
  graphical_set = tech_graphical_set('ingredient', tech_list_item_available),
}

styles.rq_tech_list_item_queued_tool_bar = {
  type = 'frame_style',
  parent = 'rq_tech_list_item_available_tool_bar',
  graphical_set = tech_graphical_set('ingredient', tech_list_item_queued),
}

styles.rq_tech_list_item_queued_head_tool_bar = {
  type = 'frame_style',
  parent = 'rq_tech_list_item_available_tool_bar',
  graphical_set = tech_graphical_set('ingredient', tech_list_item_queued_head),
}

styles.rq_tech_list_item_unavailable_tool_bar = {
  type = 'frame_style',
  parent = 'rq_tech_list_item_available_tool_bar',
  graphical_set = tech_graphical_set('ingredient', tech_list_item_unavailable),
}

styles.rq_tech_list_item_researched_tool_bar = {
  type = 'frame_style',
  parent = 'rq_tech_list_item_available_tool_bar',
  graphical_set = tech_graphical_set('ingredient', tech_list_item_researched),
}

styles.rq_tech_list_item_tool_button = {
  type = 'button_style',
  parent = 'tool_button',
  size = 24,
  padding = 0,
}

styles.rq_tech_queue_item = {
  type = 'frame_style',
  parent = 'subpanel_frame',
  padding = 2,
  horizontal_flow_style = {
    type = 'horizontal_flow_style',
    vertically_stretchable = 'off',
    vertical_align = 'center',
  },
}

styles.rq_tech_queue_item_tech_button = util.merge{
  {
    type = 'button_style',
    size = tech_queue_tech_button_size,
    padding = 0,
  },
  tech_graphical_set('button', tech_list_item_queued),
}

styles.rq_tech_queue_head_item_tech_button = util.merge{
  {
    type = 'button_style',
    size = tech_queue_tech_button_size,
    padding = 0,
  },
  tech_graphical_set('button', tech_list_item_queued_head),
}

styles.rq_tech_queue_item_buttons = {
  type = 'vertical_flow_style',
  horizontal_align = 'center',
  vertical_spacing = 0,
}

styles.rq_tech_queue_item_close_button = {
  type = 'button_style',
  parent = 'mini_button',
}

styles.rq_tech_queue_item_shift_up_button = {
  type = 'button_style',
  size = {8, 8},
  padding = 0,
  default_graphical_set = {
    filename = '__core__/graphics/arrows/table-header-sort-arrow-up-active.png',
    size = {16, 16},
    scale = 0.5
  },
  hovered_graphical_set = {
    filename = '__core__/graphics/arrows/table-header-sort-arrow-up-hover.png',
    size = {16, 16},
    scale = 0.5
  },
  clicked_graphical_set = {
    filename = '__core__/graphics/arrows/table-header-sort-arrow-up-active.png',
    size = {16, 16},
    scale = 0.5
  },
  disabled_graphical_set = util.empty_sprite(),
}

styles.rq_tech_queue_item_shift_down_button = {
  type = 'button_style',
  size = {8, 8},
  padding = 0,
  default_graphical_set = {
    filename = '__core__/graphics/arrows/table-header-sort-arrow-down-active.png',
    size = {16, 16},
    scale = 0.5
  },
  hovered_graphical_set = {
    filename = '__core__/graphics/arrows/table-header-sort-arrow-down-hover.png',
    size = {16, 16},
    scale = 0.5
  },
  clicked_graphical_set = {
    filename = '__core__/graphics/arrows/table-header-sort-arrow-down-active.png',
    size = {16, 16},
    scale = 0.5
  },
  disabled_graphical_set = util.empty_sprite(),
}

styles.rq_tech_queue_item_paused = {
  type = 'frame_style',
  parent = 'invisible_frame',
  horizontal_flow_style = {
    type = 'horizontal_flow_style',
    width = 6+tech_queue_tech_button_size+8+16+6,
    height = 6+tech_queue_tech_button_size+6,
    -- horizontally_stretchable = 'on',
    horizontal_align = 'center',
    -- vertically_stretchable = 'on',
    vertical_align = 'center',
  },
}

styles.rq_tech_queue_item_paused_unpause_button = {
  type = 'button_style',
  parent = 'tool_button',
}

styles.rq_settings_section = {
  type = 'frame_style',
  parent = 'bordered_frame',
}
