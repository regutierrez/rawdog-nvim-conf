local function tailscale_serve_gateway()
  local from_env = vim.env.HORIZON_PG_GATEWAY
  if from_env and from_env ~= "" then
    return from_env
  end
  local conf = vim.fn.expand("~/.config/akkio-vpn/client.conf")
  if vim.uv.fs_stat(conf) then
    for line in io.lines(conf) do
      local value = line:match("^%s*GATEWAY%s*=%s*(%S+)")
      if value then
        return (value:gsub("[\"']", ""))
      end
    end
  end
  return "akkio-remote.atlas-cherimoya.ts.net"
end

local function first_line(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local line = file:read("*l")
  file:close()
  if line and line ~= "" then
    return line
  end
end

local function rewrite_url_host_port(url, host, port)
  local authority = host .. ":" .. tostring(port)
  local rewritten, count = url:gsub("(@)[^/]+", "%1" .. authority, 1)
  if count == 0 then
    rewritten = url:gsub("(://)[^/]+", "%1" .. authority, 1)
  end
  return rewritten
end

-- Load Horizon production Postgres from the local URL files used by query-hz.
-- Never put the password in this git repo; rewrite onto the Tailscale Serve listener.
local function horizon_production_url()
  local home = vim.fn.expand("~")
  local url = first_line(home .. "/.config/horizon-pg/production.url")
    or first_line(home .. "/.config/horizon-pg/horizon-production.url")
    or first_line(home .. "/.cache/horizon-pg/horizon-production.url")
  if not url then
    return nil
  end
  return rewrite_url_host_port(url, tailscale_serve_gateway(), 35432)
end

return {
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
    },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
    keys = {
      { "<leader>du", "<cmd>DBUIToggle<cr>", desc = "DB UI" },
    },
    init = function()
      vim.g.db_ui_use_nerd_fonts = 1
      -- Do not run SQL on write; execute with <leader>S in the query buffer.
      vim.g.db_ui_execute_on_save = 0
      local url = horizon_production_url()
      if url then
        vim.g.dbs = {
          { name = "horizon-production", url = url },
        }
      end
    end,
  },
}
