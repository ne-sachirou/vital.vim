let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_depends()
  return ['Data.List']
endfunction

function! s:_vital_loaded(V)
  let s:List = a:V.import('Data.List')
endfunction

let s:OPERATOR_LIST = [
\  '+', '-', '*', '/', '%', '.',
\  '==', '==#', '==?',
\  '!=', '!=#', '!=?',
\  '>',  '>#',  '>?',
\  '>=', '>=#', '>=?',
\  '<',  '<#',  '<?',
\  '<=', '<=#', '<=?',
\  '=~', '=~#', '=~?',
\  '!~', '!~#', '!~?',
\  'is', 'is#', 'is?',
\  'isnot', 'isnot#', 'isnot?',
\  '||', '&&',
\]

let s:closures = {}
let s:current_function_id = 0

let s:Closure = {
\   '_arglist': [],
\   '_context': {},
\ }

function! s:Closure.call(...)
  return self.apply(a:000)
endfunction

function! s:Closure.apply(arglist)
  return call(self._function, self._arglist + a:arglist, self._context)
endfunction

function! s:Closure.with_args(...)
  return self.with_arglist(a:000)
endfunction

function! s:Closure.with_arglist(arglist)
  if empty(a:arglist)
    return self
  endif
  return s:new(self._function, self._arglist + a:arglist, self._context)
endfunction

function! s:Closure.with_context(context)
  if type(a:context) != type({})
    return self
  endif
  return s:new(self._function, self._arglist, a:context)
endfunction

function! s:Closure.with_param(param_list)
  let [arglist, context] = s:_get_arglist_and_context(a:param_list)
  if empty(arglist) && type(context) != type({})
    return self
  endif
  if type(context) != type({})
    unlet context
    let context = self._context
  endif
  return s:new(self._function, self._arglist + arglist, context)
endfunction

function! s:Closure.compose(...)
  return s:compose([self] + a:000)
endfunction

function! s:Closure.to_function()
  if !has_key(self, '_function_id')
    let self._function_id = s:_create_function_id()
    let s:closures[self._function_id] = self
  endif
  let name = s:_function_name(self._function_id)
  call s:_make_function(name, self._function_id)
  return s:_sfunc(name)
endfunction

function! s:Closure.sweep_function()
  let id = get(self, '_function_id', 0)
  let funcname = 's:' . s:_function_name(id)
  if exists('*' . funcname)
    execute 'delfunction ' . funcname
  endif
  if has_key(s:closures, id)
    call remove(s:closures, id)
  endif
endfunction

function! s:_create_function_id()
  let s:current_function_id += 1
  return s:current_function_id
endfunction

function! s:_function_name(id)
  return printf('_function_%d', a:id)
endfunction

function! s:_make_function(name, id)
  execute printf(join([
  \   'function s:%s(...)',
  \   '  return s:closures[%s].apply(a:000)',
  \   'endfunction',
  \ ], "\n"), a:name, a:id)
endfunction


function! s:is_closure(expr)
  return type(a:expr) == type({}) &&
  \      has_key(a:expr, 'call') &&
  \      type(a:expr.call) == type(function('call')) &&
  \      a:expr.call == s:Closure.call
endfunction

function! s:new(function, ...)
  let closure = deepcopy(s:Closure)
  let closure._function = a:function
  let [closure._arglist, closure._context] = s:_get_arglist_and_context(a:000)
  return closure
endfunction

function! s:from_expr(expr, ...)
  let [arglist, binding] = s:_get_arglist_and_binding(a:000)
  let context = {'binding': binding, 'expr': a:expr}
  return s:new(s:_sfunc('_eval'), arglist, context)
endfunction

function! s:from_command(command, ...)
  let [arglist, binding] = s:_get_arglist_and_binding(a:000)
  let commands = type(a:command) == type([]) ? a:command : [a:command]
  let context = {'binding': binding, 'commands': commands}
  return s:new(s:_sfunc('_execute'), arglist, context)
endfunction

function! s:from_operator(op)
  return s:from_expr(printf('a:1%sa:2', a:op))
endfunction

function! s:build(callable, ...)
  let t = type(a:callable)
  if s:is_closure(a:callable)
    return a:callable.with_param(a:000)
  elseif t == type(function('type'))
    let [arglist, context] = s:_get_arglist_and_context(a:000)
    return s:new(a:callable, arglist, context)
  elseif t == type('')
    if s:_is_operator(a:callable)
      return s:from_operator(a:callable).with_param(a:000)
    elseif a:callable[0] ==# ':'
      return call('s:from_command', [a:callable] + a:000)
    else
      return call('s:from_expr', [a:callable] + a:000)
    endif
  elseif t == type([])
    if s:List.all('type(v:val) == type("")', a:callable)
      return call('s:from_command', [a:callable] + a:000)
    endif
  endif
  throw 'vital: Closure: Can not treat as callable: ' . string(a:callable)
endfunction

function! s:call(callable, ...)
  let closure = call('s:build', [a:callable] + a:000)
  return closure.call()
endfunction

function! s:compose(...)
  let callables = reverse(copy(a:000))
  let closure = s:build(remove(callables, 0))
  for C in callables
    let next = s:build(C)
    let context = {'first': closure, 'second': next}
    let closure = s:new(s:_sfunc('_chain'), context)
    unlet C
  endfor
  return closure
endfunction


function! s:_get_arglist_and_context(args)
  let arglist = []
  for arg in a:args
    let t = type(arg)
    if t == type([])
      call extend(arglist, arg)
    elseif t == type({})
      let context = arg
    endif
    unlet arg
  endfor
  return [arglist, get(l:, 'context', 0)]
endfunction

function! s:_get_arglist_and_binding(args)
  let arglist = []
  let binding = {}
  for arg in a:args
    let t = type(arg)
    if t == type([])
      call extend(arglist, arg)
    elseif t == type({})
      call extend(binding, arg)
    endif
    unlet arg
  endfor
  return [arglist, binding]
endfunction

function! s:_is_operator(str)
  return 0 <= index(s:OPERATOR_LIST, a:str)
endfunction

function! s:_eval(...) dict
  call extend(l:, self.binding)
  try
    return eval(self.expr)
  finally
    call extend(self.binding, l:)
  endtry
endfunction

function! s:_execute(...) dict
  call extend(l:, self.binding)
  try
    execute join(self.commands, "\n")
  finally
    call extend(self.binding, l:)
  endtry
endfunction

function! s:_chain(...) dict
  return self.second.call(self.first.apply(a:000))
endfunction


function! s:_sfunc(name)
  return function(matchstr(expand('<sfile>'), '<SNR>\d\+_\ze_sfunc$') . a:name)
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
