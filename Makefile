.PHOY: test

test: deps/mini.nvim deps/budoux.lua
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Download 'mini.nvim' to use its 'mini.test' testing module
deps/mini.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/echasnovski/mini.nvim $@

deps/budoux.lua:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/atusy/budoux.lua $@
