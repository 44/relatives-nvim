local M = {}
local function noop() end

local log = { debug = noop, trace = noop, info = noop, warn = noop, error = noop, fatal = noop, needs_initialization = true, }

local function init_log_if_needed()
    if log.needs_initialization then
        local ok, pl = pcall(require, 'plenary.log')
        if ok then
            log = pl.new({
                plugin = 'relatives',
                use_console = false,
                level = vim.g.relatives_log_level or "warn"
            })
        else
            log.needs_initialization = false
        end
    end
end

M.select_related = function(opts)
    init_log_if_needed()
    log.debug('Options', opts)
    local mapping = (opts and opts.mapping) or vim.g.relatives_mapping
    log.debug('Mapping', mapping)
    if not opts then
        opts = {}
    end
    if (mapping == nil) or (next(mapping) == nil) then
        log.error("Mapping for relatives not defined")
        if vim.g.relatives_notify then
            vim.notify("Mapping for relatives not defined", "error")
        end
    end
    local ok, telescope = pcall(require, 'telescope.builtin')
    if not ok then
        log.error("Telescope not found")
        if vim.g.relatives_notify then
            vim.notify("Telescope not found")
        end
    end

    local current = vim.fn.fnamemodify(vim.fn.expand('%'), ':~:.')
    local resolved = {}
    for k, v in pairs(mapping) do
        local wo_placeholder = k
        local ptrn = vim.fn.glob2regpat(wo_placeholder)
        for i=1,9 do
            ptrn = ptrn:gsub('=' .. i, '\\([^/]*\\)')

        end
        local matched = vim.fn.matchlist(current, ptrn)
        if #matched > 0 then
            log.debug("Searching for relatives of ", current, "which is", v, "according to", ptrn, ' => ', matched[2])
            for ik, iv in pairs(mapping) do
                for ip, vp in ipairs(matched) do
                    if ip > 1 then
                        if #vp > 0 then
                            local to_find = ik:gsub('=' .. (ip - 1), vp)
                            resolved[to_find] = iv
                        end
                    end
                end
            end
        end
    end

    local matchers = {}
    for k, v in pairs(resolved) do
        log.debug("Resolved", k, v, vim.fn.glob2regpat(k))
        table.insert(matchers, vim.fn.glob2regpat(k))
    end

    local orig_entry_maker = opts.entry_maker or require('telescope.make_entry').gen_from_file(opts)

    local relatives_maker = function(line)
        local found = false
        for _, v in ipairs(matchers) do
            local m = vim.fn.match(line, v)
            if m > -1 then
                found = true
            end
        end
        if found then
            return orig_entry_maker(line)
        else
            return
        end
    end
    opts.entry_maker = relatives_maker
    telescope.find_files(opts)
end

return M
