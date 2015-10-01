" Section: Folding

function! Foldtext() abort
  if &foldmethod !=# 'syntax'
    return foldtext()
  elseif getline(v:foldstart) =~# '^diff '
    let [add, remove] = [-1, -1]
    let filename = ''
    for lnum in range(v:foldstart, v:foldend)
      if filename ==# '' && getline(lnum) =~# '^[+-]\{3\} [abciow12]/'
        let filename = getline(lnum)[6:-1]
      endif
      if getline(lnum) =~# '^+'
        let add += 1
      elseif getline(lnum) =~# '^-'
        let remove += 1
      elseif getline(lnum) =~# '^Binary '
        let binary = 1
      endif
    endfor
    if filename ==# ''
      let filename = matchstr(getline(v:foldstart), '^diff .\{-\} a/\zs.*\ze b/')
    endif
    if filename ==# ''
      let filename = getline(v:foldstart)[5:-1]
    endif
    if exists('binary')
      return 'Binary: '.filename
    else
      return (add<10&&remove<100?' ':'') . add . '+ ' . (remove<10&&add<100?' ':'') . remove . '- ' . filename
    endif
  elseif getline(v:foldstart) =~# '^# .*:$'
    let lines = getline(v:foldstart, v:foldend)
    call filter(lines, 'v:val =~# "^#\t"')
    cal map(lines,'s:sub(v:val, "^#\t%(modified: +|renamed: +)=", "")')
    cal map(lines,'s:sub(v:val, "^([[:alpha:] ]+): +(.*)", "\\2 (\\1)")')
    return getline(v:foldstart).' '.join(lines, ', ')
  endif
  return foldtext()
endfunction

function! Glogga()
  call GlogGraph(1)
endfunction

function! Glogg()
  call GlogGraph(0)
endfunction

function! GlogGraph(showAll)
  silent! wincmd P
  if !&previewwindow
    execute 'aboveleft ' . 20 . ' new'
    set previewwindow
  endif

  execute "silent %delete_"
  
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap

  let all = ""
  if a:showAll
    let all = " --all"
  endif
  let git_log_command = "git log --decorate --graph --oneline --color=always" . all
  execute "silent 0read !". git_log_command

  set nowrap
  if !AnsiEsc#IsAnsiEscEnabled(bufnr("%"))
    AnsiEsc
  endif
  normal 1G
  map <buffer> <Enter> :call OpenCommit()<CR>
endfunction

function! GotoWin(winnr) 
  let cmd = type(a:winnr) == type(0) ? a:winnr . 'wincmd w'
                                     \ : 'wincmd ' . a:winnr
  execute cmd
endfunction

function! OpenCommit()
  let line = getline(".")
  let commit = substitute(line, '.*\*\s\+\e[.\{-}m\(.\{-}\)\e.*', '\1', "g")  

  "Open in another buffer (always same place)
  let commitwinnr = bufwinnr("__Commit__")
  if commitwinnr != -1
    call GotoWin(commitwinnr)
  else
    call NewWindow(0, "__Commit__")
  endif
  execute "silent %delete_"
  
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap

  execute "silent 0read !git show" commit
  set filetype=git
  set foldmethod=syntax

  map <buffer> <Enter> :call OpenRealFile(0)<CR>
  map <buffer> <S-Enter> :call OpenRealFile(1)<CR>
endfunction

" forceSplit:
"    0 no
"    1 horizontal
"    2 vertical
function! NewWindow(forceSplit, name)
  let avaliable_windows = map(filter(range(0, bufnr('$')), 'bufwinnr(v:val)>=0 && buflisted(v:val)'), 'bufwinnr(v:val)')
  let open_command = "edit"
  if a:forceSplit || empty(avaliable_windows)
    if a:forceSplit > 1
      wincmd k
      let open_command = "vertical leftabove vsplit"
    else
      let open_command = "split"
    endif
  else
    let winnr = get(avaliable_windows, 0)
    exe winnr . "wincmd w"
    exe "file " . a:name
  endif
endfunction

function! OpenRealFile(openFrom)
  let lnum = line(".")
  let selectedLnum = lnum
  while lnum > 0
    let line = getline(lnum)
    if line =~# '^diff --git \%(a/.*\|/dev/null\) \%(b/.*\|/dev/null\)'
      let sr = substitute(line, '^diff --git \(a/.*\|/dev/null\) \(b/.*\|/dev/null\)', 
          \ 'let fromfile = "\1" | let tofile = "\2"', '')
      if sr != line
        execute sr
        if a:openFrom
          let noprefixfromfile = substitute(fromfile, '^..', '', '')
          if fromfile == "/dev/null"
            echom "file created: no from-file"
          elseif !filereadable(noprefixfromfile)
            echom "file " . noprefixfromfile . ": not exists"
          else
            exe "vsplit " . noprefixfromfile
            exe  "normal " . fromline . "G"
          endif
        else
          let noprefixtofile = substitute(tofile, '^..', '', '')
          if tofile == "/dev/null"
            echom "file deleted: no to-file"
          elseif !filereadable(noprefixtofile)
            echom "file " . noprefixtofile . ": not exists"
          else
            exe "vsplit " . noprefixtofile
            exe "normal " . toline . "G"
          endif
        endif
        break
      endif
    elseif line =~# '^@@ -\d\+,\d\+ +\d\+,\d\+'
      let sr = substitute(line, '^@@ -\(\d\+\),\(\d\+\) +\(\d\+\),\(\d\+\).*', 
                \ 'let fromline = \1 | let fromcol = \2 | let toline = \3 | let tocol = \4', '')
      if line != sr
         echo sr
        exe sr
        let offsetline = selectedLnum - lnum - 1
        let fromline += offsetline
        let toline += offsetline
      endif
    endif
    let lnum -= 1
  endwhile
endfunction

command! Glogg :call Glogg()
command! Glogga :call Glogga()

augroup gitgraph_foldtext
  autocmd!
  autocmd User Fugitive
        \ if &filetype =~# '^git\%(commit\)\=$' && &foldtext ==# 'foldtext()' |
        \    set foldtext=Foldtext() |
        \ endif
augroup END
