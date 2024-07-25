local utils = require("coq_3p.utils")

return function(spec)
  local accept_key = spec.accept_key
  if not accept_key then
    vim.api.nvim_err_writeln(
      [[Please update :: { src = "copilot", short_name = "COP", accept_key = "|something like <c-f> would work|" }]]
    )
    accept_key = "<c-f>"
  end

  COQcopilot = function()
    local esc_pum =
      vim.fn.pumvisible() == 1 and
      vim.api.nvim_replace_termcodes("<c-e>", true, true, true) or
      ""
    return esc_pum .. vim.fn["copilot#Accept"]()
  end

  -- vim.g.copilot_hide_during_completion = false
  vim.g.copilot_no_tab_map = true
  vim.g.copilot_assume_mapped = true

  vim.api.nvim_set_keymap(
    "i",
    accept_key,
    [[v:lua.COQcopilot()]],
    {nowait = true, silent = true, expr = true}
  )

  local maybe_item = function(row, col, suggestion, maybe_position)
    vim.validate {
      row = {row, "number"},
      col = {col, "number"},
      suggestion = {suggestion, "table"}
    }
    local label = suggestion.insertText or suggestion.displayText
    local new_text = suggestion.insertText or suggestion.text
    local suggestion_filter = suggestion.filterText
    local position = suggestion.position or maybe_position

    vim.validate {
      position = {position, "table"},
      label = {label, "string"},
      new_text = {new_text, "string"},
      range = {suggestion.range, "table"}
    }
    local cop_row, cop_col = position.line, position.character
    vim.validate {cop_row = {cop_row, "number"}, cop_col = {cop_col, "number"}}

    local same_row = cop_row == row
    local col_diff = col - cop_col
    local almost_same_col = math.abs(col_diff) <= utils.MAX_COL_DIFF

    if not (same_row and almost_same_col) then
      return nil
    else
      local range =
        (function()
        local bin = suggestion.range.start
        local fin = suggestion.range["end"]

        vim.validate {
          start = {bin, "table"},
          ["end"] = {fin, "table"}
        }
        vim.validate {
          end_character = {fin.character, "number"},
          end_line = {fin.line, "number"},
          start_character = {bin.character, "number"},
          start_line = {bin.line, "number"}
        }

        local tran = function(pos, lhs)
          if pos.line ~= row then
            return bin
          else
            local character = (function()
              if pos.character >= col or (lhs and pos.character == 0) then
                return pos.character
              else
                -- TODO: Calculate the diff in u16
                return pos.character + col_diff
              end
            end)()
            return {line = pos.line, character = character}
          end
        end

        return {
          start = tran(bin, true),
          ["end"] = tran(fin, false)
        }
      end)()

      local filterText = (function()
        if suggestion_filter then
          return suggestion_filter
        elseif col_diff > 0 then
          return string.sub(label, col_diff + 1)
        else
          return label
        end
      end)()

      local item = {
        preselect = true,
        label = label,
        filterText = filterText,
        documentation = label,
        textEdit = {
          newText = new_text,
          range = range
        },
        command = {
          title = "COP",
          command = "#COP"
        }
      }
      return item
    end
  end

  local pull = function()
    local copilot = vim.b._copilot

    if copilot then
      vim.validate {copilot = {copilot, "table"}}
      local maybe_suggestions = copilot.suggestions
      local maybe_position = (function()
        local params = copilot.params
        if params then
          vim.validate {params = {params, "table"}}
          return params.position
        else
          return nil
        end
      end)()

      if maybe_suggestions then
        vim.validate {maybe_suggestions = {maybe_suggestions, "table"}}
        local uuids = {}
        for _, item in ipairs(maybe_suggestions) do
          local uuid = item.uuid
          if uuid then
            vim.validate {uuid = {uuid, "string"}}
            table.insert(uuids, uuid)
          end
        end
        local uid = table.concat(uuids, "")
        return maybe_suggestions, uid, maybe_position
      end
    else
      return nil, "", nil
    end
  end

  local items = (function()
    local suggestions = {}
    local position = {}
    local uid = ""
    local function loopie()
      local maybe_suggestions, new_uid, maybe_position = pull()
      suggestions = maybe_suggestions or suggestions
      position = maybe_position or position
      if uid ~= new_uid and #suggestions >= 1 then
        utils.run_completefunc()
      end
      uid = new_uid
      vim.defer_fn(loopie, 88)
    end
    loopie()

    return function(row, col)
      local items = {}
      suggestions = pull() or suggestions
      for _, suggestion in pairs(suggestions) do
        local item = maybe_item(row, col, suggestion, position)
        if item then
          table.insert(items, item)
        end
      end
      return items
    end
  end)()

  local fn = function(args, callback)
    local row, _, u16_col = unpack(args.pos)

    callback(
      {
        isIncomplete = true,
        items = items(row, u16_col)
      }
    )
  end

  local exec = function()
    if vim.g.coqbug then
      print("#COP")
    end
  end
  return fn, {offset_encoding = "utf-16", exec = exec}
end
