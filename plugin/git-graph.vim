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

function! Glogs()
  call GlogGraph(0, 1)
endfunction

function! Glogsa()
  call GlogGraph(1, 1)
endfunction

function! Glogga()
  call GlogGraph(1, 0)
endfunction

function! Glogg()
  call GlogGraph(0, 0)
endfunction

function! GlogGraph(showAll, simplify)
  let winnr = bufwinnr("__LogGraph__")
  if winnr != -1
    call GotoWin(winnr)
  else
    call NewWindow(0, "__LogGraph__", ['__Commit__', '__DirDiff__', '__CommitFile__'])
  endif
  setlocal modifiable

  silent execute "silent %delete_"
  
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap

  let git_log_command = ["git", "log", "--decorate", "--graph", "--oneline", "--color=always"]
  if a:showAll
    call add(git_log_command, "--all")
  endif
  if a:simplify
    call add(git_log_command, "--simplify-by-decoration")
  endif
  silent execute "silent 0read !". join(git_log_command, " ")

  silent exe "file __LogGraph__"

  set nowrap
  if !AnsiEsc#IsAnsiEscEnabled(bufnr("%"))
    AnsiEsc
  endif
  normal 1G
  map <buffer> <Enter> :call Open()<CR>
  map <buffer> <Space> :call SetMark()<CR>
  setlocal nomodifiable
endfunction

function! Open()
  let line = line('.')
   if !exists('b:line') || b:line == line('.')
      call clearmatches()
      call OpenCommit()
   else
      call OpenDirDiff()
   endif
endfunction

function! GotoWin(winnr) 
  let cmd = type(a:winnr) == type(0) ? a:winnr . 'wincmd w'
                                     \ : 'wincmd ' . a:winnr
  execute cmd
endfunction

function! SetMark()
  let line = line('.')
  call clearmatches() 
  if exists('b:line') && b:line == line
    unlet b:line
    return
  endif
  let b:line = line
  call matchadd('Todo', '\%'.b:line.'l')
endfunction

function! OpenDirDiff()
  let line1 = getline(b:line)
  let line2 = getline(".")
  let commit1 = substitute(line1, '.*\*\s\+\e[.\{-}m\(.\{-}\)\e.*', '\1', "g")  
  let commit2 = substitute(line2, '.*\*\s\+\e[.\{-}m\(.\{-}\)\e.*', '\1', "g")  

  "Open in another buffer (always same place)
  let dirdiffwinnr = bufwinnr("__DirDiff__")
  if dirdiffwinnr != -1
    call GotoWin(dirdiffwinnr)
  else
    call NewWindow(0, "__DirDiff__", ['__LogGraph__', '__Commit__'])
  endif
  setlocal modifiable
  execute "silent %delete_"
  
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap

  execute "silent 0read !git ls-tree -r --name-only" commit1

  let pos = 0
  let b:folded = [-1]
  for i in systemlist("git diff --name-status " . commit1 . " " . commit2)
    let statusline = split(i, '\t')
    let pos += 1
    while pos < line('$')
      if getline(pos) == statusline[1]
        call add(b:folded, 0)
        call setline(pos, getline(pos) . " (" . statusline[0] . ")")
        break
      else
        call add(b:folded, 1)
      endif
      let pos += 1
    endwhile
  endfor
  while pos < line('$')
    call add(b:folded, 1)
    let pos += 1
  endwhile
  set foldexpr=b:folded[v:lnum]
  set foldmethod=expr

  map <buffer> <Enter> :call OpenDirDiffFile(commit1, commit2, line('.'))<CR>
  setlocal nomodifiable
endfunction

function! OpenDifDiffFile(commit1, commit2, lnum)
  if b:folded[lnum] == 0
     "modified, open diff

  else
     "can dest file
endfunction

function! OpenCommit()
  let line = getline(".")
  let commit = substitute(line, '.*\*\s\+\e[.\{-}m\(.\{-}\)\e.*', '\1', "g")  

  "Open in another buffer (always same place)
  let commitwinnr = bufwinnr("__Commit__")
  if commitwinnr != -1
    call GotoWin(commitwinnr)
  else
    call NewWindow(0, "__Commit__", ['__LogGraph__', '__DirDiff__', '__CommitFile__'])
  endif
  setlocal modifiable
  execute "silent %delete_"
  
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap

  execute "silent 0read !git show" commit
  set filetype=git
  set foldmethod=syntax

  "TODO: commit file should be opened
  exe "map <buffer> r :call OpenShowFile('".commit."', 1, 1)<CR>"
  exe "map <buffer> R :call OpenShowFile('".commit."', 0, 1)<CR>"
  exe "map <buffer> c :call OpenShowFile('".commit."', 1, 0)<CR>"
  exe "map <buffer> C :call OpenShowFile('".commit."', 0, 0)<CR>"
  setlocal nomodifiable
endfunction

" forceSplit:
"    0 no
"    1 horizontal
"    2 vertical
function! NewWindow(forceSplit, name, excluded)
  let buffers_from_windows = map(range(1, winnr('$')), 'winbufnr(v:val)')
  let match_window = map(filter(copy(buffers_from_windows), 'bufname(v:val) == a:name'), 'bufwinnr(v:val)')
  let winnr = 0
  if empty(match_window)
    let excluded_buffers = ""
    if !empty(a:excluded)
      for i in a:excluded
        let excluded_buffers = excluded_buffers . ' && bufname(v:val) != "' . i . '"'
      endfor
    endif
    let avaliable_windows = map(filter(copy(buffers_from_windows), 'buflisted(v:val)' . excluded_buffers), 'bufwinnr(v:val)')
    let winnr = get(avaliable_windows, 0)
  else
    let winnr = get(match_window, 0)
  endif
  if a:forceSplit || winnr == 0
    if a:forceSplit > 1
      wincmd k
      let open_command = "vertical leftabove new"
    else
      let open_command = "new"
    endif
    exe open_command
  else
    silent exe winnr . "wincmd w"
  endif
  silent exe "file " . a:name
endfunction

function! OpenShowFile(commit, openFrom, workdir)
  let lnum = line(".")
  let selectedLnum = lnum
  let b:parents = [a:commit."^"]
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
          else
            let noprefixfromfile = substitute(fromfile, 'a/', '', '')
            if a:workdir
              if !filereadable(noprefixfromfile)
                echom "file " . noprefixfromfile . ": not exists"
              else
                exe "vsplit " . noprefixfromfile
                if exists('fromline')
                  exe  "normal " . fromline . "G"
                endif
              endif
            else
              if len(b:parents) == 1
                call OpenCommitFile(b:parents[0], noprefixfromfile)
              else
                let commitpos = inputdialog(map(copy(b:parents), "v:key+1.'. '.v:val"))
                if commitpos > 0
                  let parent_commit = b:parents[commitpos-1]
                  call OpenCommitFile(parent_commit, noprefixfromfile)
                endif
              endif
            endif
          endif
        else
          let noprefixtofile = substitute(tofile, '^..', '', '')
          if tofile == "/dev/null"
            echom "file deleted: no to-file"
          else
            let noprefixtofile = substitute(tofile, 'b/', '', '')
            if a:workdir
              if !filereadable(noprefixtofile)
                echom "file " . noprefixtofile . ": not exists"
              else
                exe "vsplit " . noprefixtofile
                if exists('toline')
                  exe "normal " . toline . "G"
                endif
              endif
            else
              call OpenCommitFile(a:commit,noprefixtofile)
            endif
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
    elseif line =~# "^Merge: "
      let b:parents = split(substitute(line, "^Merge: ")," ")
    endif
    let lnum -= 1
  endwhile
endfunction

function! OpenCommitFile(commit, filename)

  "Open in another buffer (always same place)
  let commitwinnr = bufwinnr("__CommitFile__")
  if commitwinnr != -1
    call GotoWin(commitwinnr)
  else
    call NewWindow(0, "__CommitFile__", ['__LogGraph__', '__DirDiff__', '__Commit__'])
  endif
  setlocal modifiable
  execute "silent %delete_"
  
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap

  execute "silent 0read !git show " . a:commit . ":" . a:filename
  execute "set filetype=". substitute(a:filename, '^.*\.', '', '')
  setlocal nomodifiable
endfunction

command! Glogg :call Glogg()
command! Glogga :call Glogga()
command! Glogs :call Glogs()
command! Glogsa :call Glogsa()

augroup gitgraph_foldtext
  autocmd!
  autocmd User Fugitive
        \ if &filetype =~# '^git\%(commit\)\=$' && &foldtext ==# 'foldtext()' |
        \    set foldtext=Foldtext() |
        \ endif
augroup END

autocmd BufEnter * if expand('<amatch>')==''|call fugitive#detect(getcwd())|endif
