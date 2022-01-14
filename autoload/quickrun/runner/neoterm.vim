" quickrun: runner/neoterm: Runs by neovim terminal feature.
" Author : skanehira
" License: zlib License

let s:is_win = has('win32')
let s:runner = {
\   'config': {
\     'name': 'default',
\     'opener': 'new',
\     'into': 0,
\   },
\ }

let s:wins = {}

function s:runner.validate() abort
  if !exists("*termopen")
    throw 'Needs +termopen feature.'
  endif
  if !s:is_win && !executable('sh')
    throw 'Needs "sh" on other than MS Windows.'
  endif
endfunction

function s:runner.init(session) abort
  let a:session.config.outputter = 'null'
endfunction

function s:runner.run(commands, input, session) abort
  let command = join(a:commands, ' && ')
  if a:input !=# ''
    let inputfile = a:session.tempname()
    call writefile(split(a:input, "\n", 1), inputfile, 'b')
    let command = printf('(%s) < %s', command, inputfile)
  endif
  let cmd_arg = s:is_win ? printf('cmd.exe /c (%s)', command)
  \                      : ['sh', '-c', command]
  let options = {
  \   'exit_cb': self._job_exit_cb,
  \ }

  let self._key = a:session.continue()
  let prev_winid = win_getid()

  let jumped = s:goto_last_win(self.config.name)
  if !jumped
    execute self.config.opener
    let s:wins[self.config.name] += [win_getid()]
  endif
  let self._jobid = termopen(cmd_arg, options)
  setlocal bufhidden=wipe
  if !self.config.into
    call win_gotoid(prev_winid)
    " NOTE: if startinsert when TermOpen event, we need to change to normal mode.
    call feedkeys("\<Esc>")
  endif
endfunction

function s:runner.sweep() abort
  if has_key(self, '_jobid') && self._jobid > 0
    while jobwait([self._jobid], 0)[0] == -1
      call jobstop(self._jobid)
    endwhile
  endif
endfunction

function s:runner._job_exit_cb(job, exit_status, event) abort
  if has_key(self, '_job_exited')
    call quickrun#session#call(self._key, 'finish', a:exit_status)
  else
    let self._job_exited = a:exit_status
  endif
endfunction

function s:goto_last_win(name) abort
  if !has_key(s:wins, a:name)
    let s:wins[a:name] = []
  endif

  " sweep
  call filter(s:wins[a:name], 'win_id2tabwin(v:val)[0] != 0')

  for win_id in s:wins[a:name]
    let winnr = win_id2win(win_id)
    if winnr
      call win_gotoid(win_id)
      call feedkeys("\<Esc>")
      return 1
    endif
  endfor
  return 0
endfunction

function quickrun#runner#neoterm#new() abort
  return deepcopy(s:runner)
endfunction
