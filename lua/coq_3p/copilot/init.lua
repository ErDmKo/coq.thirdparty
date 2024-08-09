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

  local pull = function()
    local copilot = vim.b._copilot

    if copilot then
      vim.validate {copilot = {copilot, "table"}}
      local suggestions = copilot.suggestions
      vim.validate {suggestions = {suggestions, "table", true}}
      return suggestions
    else
      return nil
    end
  end

  local items = function()
    local items = {}
    local suggestions = pull() or {}
    for _, item in pairs(suggestions) do
      table.insert(
        items,
        vim.tbl_deep_extend(
          "force",
          {
            item,
            {
              command = {
                title = "COP",
                command = "#COP"
              }
            }
          }
        )
      )
    end
    return items
  end

  local fn = function(args, callback)
    callback(
      {
        items = items()
      }
    )
  end

  local exec = function()
    if vim.g.coqbug then
      print("#COP")
    end
  end
  return nil, {offset_encoding = "utf-16", exec = exec, ln = fn}
end
