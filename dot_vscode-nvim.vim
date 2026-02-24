augroup vimrc
  autocmd!
augroup END


set history=10000
set nobackup
set noswapfile
set noundofile
set clipboard=unnamedplus

nnoremap ; :
nnoremap : ;
vnoremap ; :
vnoremap : ;

nmap k   gk
nmap j   gj
vmap k   gk
vmap j   gj

command! SourceVimrc source ~/.vscode-nvim.vim

nnoremap <expr>0  col('.') == 1 ? '^' : '0'
nnoremap <expr>^  col('.') == 1 ? '^' : '0'

nnoremap _  :sp<CR>
nnoremap <bar>  :vsp<CR>

nnoremap <C-l>  i<Space><Esc><Right>
nnoremap <C-h>  i<Space><Esc>

nnoremap <Space>/  *<C-o>
nnoremap g<Space>/ g*<C-o>

nnoremap <expr> n <SID>search_forward_p() ? 'nzv' : 'Nzv'
nnoremap <expr> N <SID>search_forward_p() ? 'Nzv' : 'nzv'
vnoremap <expr> n <SID>search_forward_p() ? 'nzv' : 'Nzv'
vnoremap <expr> N <SID>search_forward_p() ? 'Nzv' : 'nzv'

function! s:search_forward_p()
  return exists('v:searchforward') ? v:searchforward : 1
endfunction

augroup my_vimrc
  autocmd!
augroup END

command! -bang -nargs=*
\   MyAutocmd
\   autocmd<bang> my_vimrc <args>

set updatetime=300
if exists('g:vscode')
  MyAutocmd CursorHold * if !get(b:, "hint_poped") | call VSCodeCall('editor.action.showHover') | let b:hint_poped = v:true | endif
  MyAutocmd CursorMoved * let b:hint_poped = v:false
endif

set helplang=ja,en

function! s:split(...) abort
    let direction = a:1
    let file = exists('a:2') ? a:2 : ''
    call VSCodeCall(direction ==# 'h' ? 'workbench.action.splitEditorDown' : 'workbench.action.splitEditorRight')
    if !empty(file)
        call VSCodeExtensionNotify('open-file', expand(file), 'all')
    endif
endfunction

" command! -complete=file -nargs=? Split call <SID>split('h', <q-args>)
" command! -complete=file -nargs=? Vsplit call <SID>split('v', <q-args>)

