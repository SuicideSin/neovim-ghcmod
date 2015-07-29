if !has('nvim')
  finish
endif

if exists("g:neovim_ghcmod_loaded")
  finish
endif

let g:neovim_ghcmod_loaded = 1

setlocal comments=s1fl:{-,mb:-,ex:-},:--
setlocal formatoptions-=cro formatoptions+=j
setlocal iskeyword+='

if !exists('g:ghc_modi_executable')
  let g:ghc_modi_executable = "ghc-modi"
endif

let s:resp1 = '^\([0-9]\+\) \([0-9]\+\) \([0-9]\+\) \([0-9]\+\) "\(.*\)"'
let s:resp2 = '^function\n\([0-9]\+\) \([0-9]\+\) \([0-9]\+\) \([0-9]\+\)\n\(.*\)'

let s:ghc_modi_buffer = []
let s:command_queue   = []

function! s:process_ghc_modi_buffer()
  let l:rsp = join(s:ghc_modi_buffer, "\n")
  let l:cmd = s:command_queue[0]

  let s:command_queue = s:command_queue[1:]

  let l:mth = matchlist(l:rsp, l:cmd.pattern)

  if (len(l:mth) >= 6)
    call l:cmd.func(l:cmd.cmd, l:mth)
  endif
endfunction

function! s:ghc_modi_handler(job, data, event)
  let l:skipnext = 0
  for i in a:data
    if !l:skipnext
      if (i == "OK")
        call s:process_ghc_modi_buffer()
        let s:ghc_modi_buffer = []
        let l:skipnext = 1
      else
        let s:ghc_modi_buffer += [i]
      endif
    else
      let l:skipnext = 0
    endif
  endfor
endfunction

let s:ghc_modi_job = jobstart( [g:ghc_modi_executable],
     \ { 'on_stdout': function('s:ghc_modi_handler'),
     \   'on_exit': function('s:ghc_modi_handler') }
  \)

function! s:runCmd(cmd, args)
  update
  let s:command_queue += [a:args]
  call jobsend(s:ghc_modi_job, join(a:cmd, " ") . "\n")
endfunction

function! s:replaceBlock(cmd, mth)
  let l:mrk = getpos("'a")

  call cursor(a:mth[3], a:mth[4])
  normal ma
  call cursor(a:mth[1], a:mth[2])
  normal d`ax
  exe a:cmd . a:mth[5]
  call cursor(a:mth[1], a:mth[2])

  call setpos("'a", l:mrk)
endfunction

function! s:insertBlock(cmd, mth)
  call cursor(a:mth[3], a:mth[4])
  exe a:cmd . a:mth[5]
  call cursor(a:mth[1], a:mth[2])
endfunction

function! ghcmod#caseSplit()
  let l:cmd = [ "split",
              \ expand('%'),
              \ line("."),
              \ virtcol("."),
              \ ]

  let l:args = { 'pattern': s:resp1,
               \ 'cmd': 'normal i',
               \ 'func': function('s:replaceBlock'),
               \ }

  call s:runCmd(l:cmd, l:args)
endfunction

function! ghcmod#addDecl()
  let l:cmd = [ "sig",
              \ expand('%'),
              \ line("."),
              \ virtcol("."),
              \ ]

  let l:args = { 'pattern': s:resp2,
               \ 'cmd': 'normal o',
               \ 'func': function('s:insertBlock'),
               \ }

  call s:runCmd(l:cmd, l:args)
endfunction

function! ghcmod#refine()
  let l:expr = input("Enter expression: ")
  let l:cmd  = [ "refine",
               \ expand('%'),
               \ line("."),
               \ virtcol("."),
               \ l:expr,
               \ ]

  let l:args = { 'pattern': s:resp1,
               \ 'cmd': 'normal a',
               \ 'func': function('s:replaceBlock'),
               \ }

  call s:runCmd(l:cmd, l:args)
endfunction

command! -buffer -nargs=0 GhcModCaseSplit call ghcmod#caseSplit()
command! -buffer -nargs=0 GhcModAddDecl call ghcmod#addDecl()
command! -buffer -nargs=0 GhcModRefine call ghcmod#refine()
