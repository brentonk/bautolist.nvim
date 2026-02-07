rockspec_format = '3.0'
package = 'bautolist.nvim'
version = 'scm-1'

source = {
  url = 'git+https://github.com/brentonk/bautolist.nvim',
}

dependencies = {
  'lua >= 5.1',
}

test_dependencies = {
  'lua >= 5.1',
  'nlua',
}

build = {
  type = 'builtin',
  copy_directories = {},
}
