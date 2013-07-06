" Utilities for list.

let s:save_cpo = &cpo
set cpo&vim

function! s:pop(list)
  return remove(a:list, -1)
endfunction

function! s:push(list, val)
  call add(a:list, a:val)
  return a:list
endfunction

function! s:shift(list)
  return remove(a:list, 0)
endfunction

function! s:unshift(list, val)
  return insert(a:list, a:val)
endfunction

" Removes duplicates from a list.
function! s:uniq(list, ...)
  let list = a:0 ? map(copy(a:list), printf('[v:val, %s]', a:1)) : copy(a:list)
  let i = 0
  let seen = {}
  while i < len(list)
    let key = string(a:0 ? list[i][1] : list[i])
    if has_key(seen, key)
      call remove(list, i)
    else
      let seen[key] = 1
      let i += 1
    endif
  endwhile
  return a:0 ? map(list, 'v:val[0]') : list
endfunction

function! s:clear(list)
  if !empty(a:list)
    unlet! a:list[0 : len(a:list) - 1]
  endif
  return a:list
endfunction

" Concatenates a list of lists.
" XXX: Should we verify the input?
function! s:concat(list)
  let list = []
  for Value in a:list
    let list += Value
  endfor
  return list
endfunction

" Flattens a list.
function! s:flatten(list, ...)
  let limit = a:0 > 0 ? a:1 : -1
  let list = []
  if limit == 0
    return a:list
  endif
  let limit -= 1
  for Value in a:list
    if type(Value) == type([])
      let list += s:flatten(Value, limit)
    else
      call add(list, Value)
    endif
    unlet! Value
  endfor
  return list
endfunction

" Sorts a list with expression to compare each two values.
" a:a and a:b can be used in {expr}.
function! s:sort(list, expr)
  if type(a:expr) == type(function('function'))
    return sort(a:list, a:expr)
  endif
  let s:expr = a:expr
  return sort(a:list, 's:_compare')
endfunction

function! s:_compare(a, b)
  return eval(s:expr)
endfunction

" Sorts a list using a set of keys generated by mapping the values in the list
" through the given expr.
" v:val is used in {expr}
function! s:sort_by(list, expr)
  let pairs = map(a:list, printf('[v:val, %s]', a:expr))
  return map(s:sort(pairs,
  \      'a:a[1] ==# a:b[1] ? 0 : a:a[1] ># a:b[1] ? 1 : -1'), 'v:val[0]')
endfunction

function! s:max(list, expr)
  echoerr 'Data.List.max() is obsolete. Use its max_by() instead.'
  return s:max_by(a:list, a:expr)
endfunction

" Returns a maximum value in {list} through given {expr}.
" Returns 0 if {list} is empty.
" v:val is used in {expr}
function! s:max_by(list, expr)
  if empty(a:list)
    return 0
  endif
  let list = map(copy(a:list), a:expr)
  return a:list[index(list, max(list))]
endfunction

function! s:min(list, expr)
  echoerr 'Data.List.min() is obsolete. Use its min_by() instead.'
  return s:min_by(a:list, a:expr)
endfunction

" Returns a minimum value in {list} through given {expr}.
" Returns 0 if {list} is empty.
" v:val is used in {expr}
" FIXME: -0x80000000 == 0x80000000
function! s:min_by(list, expr)
  return s:max(a:list, '-(' . a:expr . ')')
endfunction

" Returns List of character sequence between [a:from, a:to]
" e.g.: s:char_range('a', 'c') returns ['a', 'b', 'c']
function! s:char_range(from, to)
  return map(
  \   range(char2nr(a:from), char2nr(a:to)),
  \   'nr2char(v:val)'
  \)
endfunction

" Returns true if a:list has a:Value.
" Returns false otherwise.
function! s:has(list, Value)
  return index(a:list, a:Value) isnot -1
endfunction

" Returns true if a:list[a:index] exists.
" Returns false otherwise.
" NOTE: Returns false when a:index is negative number.
function! s:has_index(list, index)
  " Return true when negative index?
  " let index = a:index >= 0 ? a:index : len(a:list) + a:index
  return 0 <= a:index && a:index < len(a:list)
endfunction

" similar to Haskell's Data.List.span
function! s:span(f, xs)
  let border = len(a:xs)
  for i in range(len(a:xs))
    if !eval(substitute(a:f, 'v:val', string(a:xs[i]), 'g'))
      let border = i
      break
    endif
  endfor
  return border == 0 ? [[], copy(a:xs)] : [a:xs[: border - 1], a:xs[border :]]
endfunction

" similar to Haskell's Data.List.break
function! s:break(f, xs)
  return s:span(printf('!(%s)', a:f), a:xs)
endfunction

" similar to Haskell's Data.List.takeWhile
function! s:take_while(f, xs)
  return s:span(a:f, a:xs)[0]
endfunction

" similar to Haskell's Data.List.partition
function! s:partition(f, xs)
  return [filter(copy(a:xs), a:f), filter(copy(a:xs), '!(' . a:f . ')')]
endfunction

" similar to Haskell's Prelude.all
function! s:all(f, xs)
  return !s:any(printf('!(%s)', a:f), a:xs)
endfunction

" similar to Haskell's Prelude.any
function! s:any(f, xs)
  return !empty(filter(map(copy(a:xs), a:f), 'v:val'))
endfunction

" similar to Haskell's Prelude.and
function! s:and(xs)
  return s:all('v:val', a:xs)
endfunction

" similar to Haskell's Prelude.or
function! s:or(xs)
  return s:any('v:val', a:xs)
endfunction

" similar to Haskell's Prelude.foldl
function! s:foldl(f, init, xs)
  let memo = a:init
  for x in a:xs
    let expr = substitute(a:f, 'v:val', string(x), 'g')
    let expr = substitute(expr, 'v:memo', string(memo), 'g')
    unlet memo
    let memo = eval(expr)
  endfor
  return memo
endfunction

" similar to Haskell's Prelude.foldl1
function! s:foldl1(f, xs)
  if len(a:xs) == 0
    throw 'foldl1'
  endif
  return s:foldl(a:f, a:xs[0], a:xs[1:])
endfunction

" similar to Haskell's Prelude.foldr
function! s:foldr(f, init, xs)
  let memo = a:init
  for i in reverse(range(0, len(a:xs) - 1))
    let x = a:xs[i]
    let expr = substitute(a:f, 'v:val', string(x), 'g')
    let expr = substitute(expr, 'v:memo', string(memo), 'g')
    unlet memo
    let memo = eval(expr)
  endfor
  return memo
endfunction

" similar to Haskell's Prelude.fold11
function! s:foldr1(f, xs)
  if len(a:xs) == 0
    throw 'foldr1'
  endif
  return s:foldr(a:f, a:xs[-1], a:xs[0:-2])
endfunction

" similar to python's zip()
function! s:zip(...)
  return map(range(min(map(copy(a:000), 'len(v:val)'))), "map(copy(a:000), 'v:val['.v:val.']')")
endfunction

" Inspired by Ruby's with_index method.
function! s:with_index(list, ...)
  let base = a:0 > 0 ? a:1 : 0
  return s:zip(a:list, range(base, len(a:list)+base-1))
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:
