" This vim plugin connects the dev-tools scripts to custom vim commands
" All commands can be called with additional parameters (EX: >CC -l -r)
"
" In your .vimrc file make sure to insert:
" 		source /path/to/tools-plugin.vim
"
" All dev-tool scripts that are meant to be callable from vim will have a help
" feature. Simply call the vim command with the '--help' flag to get the
" dev-tool script description

" Function wrappers for the dev-tools scripts
function! LoadCPython(...)
	w
	:let l:args = expand('%:p').' '.join(a:000)
	execute "!write-out-cpython.sh ".l:args
endfunction
function! ArduinoCompile(...)
	w
	:let l:args = join(a:000).' '.getcwd()
	execute "!arduino-controller.sh -u ".l:args
endfunction

" Custom command for the wrapper functions
:command -nargs=* CC call LoadCPython(<f-args>)
:command -nargs=* AA call ArduinoCompile(<f-args>)

