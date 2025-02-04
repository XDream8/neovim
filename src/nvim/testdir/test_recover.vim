" Test :recover

source check.vim

func Test_recover_root_dir()
  " This used to access invalid memory.
  split Xtest
  set dir=/
  call assert_fails('recover', 'E305:')
  close!

  if has('win32')
    " can write in / directory on MS-Windows
    let &directory = 'F:\\'
  elseif filewritable('/') == 2
    set dir=/notexist/
  endif
  call assert_fails('split Xtest', 'E303:')

  " No error with empty 'directory' setting.
  set directory=
  split XtestOK
  close!

  set dir&
endfunc

" Make a copy of the current swap file to "Xswap".
" Return the name of the swap file.
func CopySwapfile()
  preserve
  " get the name of the swap file
  let swname = split(execute("swapname"))[0]
  let swname = substitute(swname, '[[:blank:][:cntrl:]]*\(.\{-}\)[[:blank:][:cntrl:]]*$', '\1', '')
  " make a copy of the swap file in Xswap
  set binary
  exe 'sp ' . swname
  w! Xswap
  set nobinary
  return swname
endfunc

" Inserts 10000 lines with text to fill the swap file with two levels of pointer
" blocks.  Then recovers from the swap file and checks all text is restored.
"
" We need about 10000 lines of 100 characters to get two levels of pointer
" blocks.
func Test_swap_file()
  set directory=.
  set fileformat=unix undolevels=-1
  edit! Xtest
  let text = "\tabcdefghijklmnoparstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnoparstuvwxyz0123456789"
  let i = 1
  let linecount = 10000
  while i <= linecount
    call append(i - 1, i . text)
    let i += 1
  endwhile
  $delete

  let swname = CopySwapfile()

  new
  only!
  bwipe! Xtest
  call rename('Xswap', swname)
  recover Xtest
  call delete(swname)
  let linedollar = line('$')
  call assert_equal(linecount, linedollar)
  if linedollar < linecount
    let linecount = linedollar
  endif
  let i = 1
  while i <= linecount
    call assert_equal(i . text, getline(i))
    let i += 1
  endwhile

  set undolevels&
  enew! | only
endfunc

func Test_nocatch_process_still_running()
  let g:skipped_reason = 'test_override() is N/A'
  return
  " sysinfo.uptime probably only works on Linux
  if !has('linux')
    let g:skipped_reason = 'only works on Linux'
    return
  endif
  " the GUI dialog can't be handled
  if has('gui_running')
    let g:skipped_reason = 'only works in the terminal'
    return
  endif

  " don't intercept existing swap file here
  au! SwapExists

  " Edit a file and grab its swapfile.
  edit Xswaptest
  call setline(1, ['a', 'b', 'c'])
  let swname = CopySwapfile()

  " Forget we edited this file
  new
  only!
  bwipe! Xswaptest

  call rename('Xswap', swname)
  call feedkeys('e', 'tL')
  redir => editOutput
  edit Xswaptest
  redir END
  call assert_match('E325: ATTENTION', editOutput)
  call assert_match('file name: .*Xswaptest', editOutput)
  call assert_match('process ID: \d* (STILL RUNNING)', editOutput)

  " Forget we edited this file
  new
  only!
  bwipe! Xswaptest

  " pretend we rebooted
  call test_override("uptime", 0)
  sleep 1

  call rename('Xswap', swname)
  call feedkeys('e', 'tL')
  redir => editOutput
  edit Xswaptest
  redir END
  call assert_match('E325: ATTENTION', editOutput)
  call assert_notmatch('(STILL RUNNING)', editOutput)

  call test_override("ALL", 0)
  call delete(swname)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
