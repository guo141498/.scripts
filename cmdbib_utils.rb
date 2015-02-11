#!/usr/bin/ruby
# encoding: utf-8

require 'curses'
include Curses

# The window with frame
class Framewin
  attr_reader :cont
  attr_accessor :framewin

  public

  def initialize(height, width, lsft, csft, frame = false)
    @frame, @h, @w = frame, height - 1, width - 1

    @framewin = Window.new(height + 2, width + 2, lsft, csft) if @frame

    lsft, csft = lsft + 1, csft + 1 if @frame
    @cont = Window.new(height, width, lsft, csft)
  end

  def refresh(pos = false)
    drawframe(pos) if @frame
    @cont.refresh
  end

  def freshframe
    @framewin.box(@frame[0], @frame[1])
    @framewin.refresh
  end

  private

  def drawframe(pos)
    getbkg(pos)
    freshframe

    @cont.setpos(0, 0)
    @cont.addstr(@bkgd)
  end

  def getbkg(pos)
    @bkgd = ''
    line, col = pos || [@h, @w]
    areabf(line, col) { |ln, cl| @bkgd << inchar(ln, cl) }
  end

  def areabf(line, col)
    (0..line - 1).each { |ln| (0..@w).each { |cl| yield(ln, cl) } }
    (0..col).each { |cl| yield(line, cl) }
  end

  def inchar(line, col)
    @cont.setpos(line, col)
    @cont.inch
  end
end

# The basic utils for menu
module MenuUtils
  public

  def setctrl(qkey, dkey, ukey)
    @qkey, @dkey, @ukey = qkey, dkey, ukey
  end

  def set(curse, scurse, list = @list)
    @list = list[0].is_a?(Array) ? list : [list]
    @curse, @scurse = curse, scurse
    @contlen = @list[0].size < @maxlen ? @list[0].size : @maxlen
    @win.each { |win| win.cont.clear }
    mrefresh
  end

  def setcol(visible, mainm = @mainm)
    @visible, @mainm = visible, mainm
  end

  def current(col = @mainm)
    @list[col][@curse % listsize].to_s
  end

  private

  def pitem(col, ind)
    pointstr(col, @list[col][ind % listsize].to_s, ind - @scurse)
  end

  def colrefresh(col)
    @win[col].freshframe
    (@scurse..@scurse + @contlen - 1).each { |ind| pitem(col, ind) }

    @win[col].cont.refresh
    frefresh(col)
  end

  def pointstr(col, strs, line)
    pair = @visible[col]
    @win[col].cont.attron(color_pair(pair)) if pair != true
    @win[col].cont.setpos(line, 0)
    @win[col].cont.addstr(fillstr(strs, col))
    @win[col].cont.attroff(color_pair(pair)) if pair != true
  end

  def theta(x)
    x > 0 ? x : 0
  end

  def fillstr(str, col = @mainm)
    str + ' ' * theta(@width[col] - str.size)
  end

  def frefresh(col)
    @win[col].cont.attron(A_STANDOUT)
    pointstr(col, current(col), @curse - @scurse)
    @win[col].cont.attroff(A_STANDOUT)
    @win[col].cont.refresh
  end

  def listsize
    @list[0].size == 0 ? 1 : @list[0].size
  end

  def cursedown
    @curse += 1
    @scurse += 1 if @scurse == @curse - @maxlen
  end

  def curseup
    @curse -= 1
    @scurse -= 1 if @scurse == @curse + 1
  end

  def jumphead
    (@curse, @scurse) = [0, 0]
  end

  def jumptail
    (@curse, @scurse) = [@list[0].size - 1, @list[0].size - @contlen]
  end
end

# Creating a menu
class Menu
  include MenuUtils
  attr_reader :win, :curse, :scurse

  public

  def initialize(list, posi, length = [20, false], width = nil, frame = false)
    @list = list[0].is_a?(Array) ? list : [list]
    ininumbers(posi, length, width)

    cw = ->(e) { Framewin.new(@maxlen, @width[e], @lsft, @csft[e] + 1, frame) }
    @win = (0..@csft.size - 1).reduce([]) { |a, e| a << cw.call(e) }
    @win.each { |win| win.cont.keypad(true) }

    @qkey, @dkey, @ukey = ['q', ' ', 10], ['j', KEY_DOWN, 9], ['k', KEY_UP]
  end

  def get
    curs_set(0)

    loop do
      char = mrefresh.getch
      deal(char)
      break if @qkey.include?(char)
    end
    current
  end

  def mrefresh
    @visible
      .each_with_index { |bool, ind| colrefresh(ind) if bool && @list[ind] }
    @win[@mainm].cont
  end

  def to_a
    @list[@mainm]
  end

  private

  def ininumbers(posi, length, width)
    @lsft, @csft = posi.is_a?(Fixnum) ? [posi, [0]] : [posi[0], posi[1..-1]]
    @csft.map { |x| x + 1 }
    (mlen, fix) = [*length] << false

    @contlen = @list[0].size < mlen ? @list[0].size : mlen
    @maxlen = fix ? mlen : @contlen

    @curse, @scurse, @mainm, @visible = 0, 0, 0, @csft.map { true }

    lastw = width || @list[0].map { |x| x.size }.max + 1
    @width = @csft.each_cons(2).map { |pvs, nxt| nxt - pvs - 1 } << lastw
  end

  def deal(char)
    return if @list[0].empty?

    eolist = @curse == @list[0].size - 1

    case true
    when @dkey.include?(char) then eolist ? jumphead : cursedown
    when @ukey.include?(char) then @curse == 0 ? jumptail : curseup
    end
  end
end

# The advance menu that support extra dealing
class AdvMenu < Menu
  attr_reader :char
  attr_accessor :curse, :scurse

  def get
    curs_set(0)

    loop do
      @char = mrefresh.getch
      deal(@char)
      yield(current, @char) if block_given?
      break if @qkey.include?(@char)
    end
    @char
  end
end

# The pointer about where should the item print, and which is the current item
class Pointer
  attr_reader :segment, :location, :len, :pst, :state

  public

  def initialize(array, segsize, pst, state)
    warn = ->() { puts 'Warning:: There is an item too long' }
    warn.call if !array.empty? && segsize < array.max
    @segsize, @len, @pst, @state = segsize, array, pst, state
    @seg, @cur, @segment, @location = 0, 0, [0], [0]
    array.each { |num| addnum(num) }
  end

  def up
    @pst = (@pst + 1) % @len.size
    @segment[@pst] != @segment[@pst - 1]
  end

  def down
    @pst = (@pst - 1) % @len.size
    @segment[@pst] != @segment[(@pst + 1) % @len.size]
  end

  def add(num)
    addnum(num)
    @len << num
    @pst = @len.size - 1
  end

  def page(order)
    return if @len.empty?
    (@segment.index(@segment[order])..@segment[0..-2].rindex(@segment[order]))
      .each { |od| yield(od) }
  end

  def chgstat
    @state = @state == :focus ? :picked : :focus
  end

  private

  def addnum(num)
    (@seg, @cur) =
      @cur + num <= @segsize ? [@seg, @cur + num] : chgpage(num)
    @segment << @seg
    @location << @cur
  end

  def chgpage(num)
    @segment[-1], @location[-1] = @segment[-1] + 1, 0
    [@seg + 1, num]
  end
end

# Some methods added to Array
class Array
  def swap!(od1, od2)
    self[od1], self[od2] = self[od2], self[od1]
  end

  def swapud!(order, uord)
    od2 = uord == :u ? (order - 1) % size : (order + 1) % size
    swap!(order, od2)
  end
end

# To store a string in the format with position information of each character
class TxtFile
  attr_reader :curse, :array, :position

  public

  def initialize(string, maxcols)
    @array, @maxcols, @position = string.each_char.to_a << :end, maxcols, []
    @curse = @array.size - 1
    getposition(0)
  end

  def string
    @array[0..-2].join('')
  end

  def each(bgn = 0)
    (bgn..@array.size - 2)
      .each { |ind| yield(letter(ind), x(ind), y(ind)) }
  end

  def letter(curse = @curse)
    @array[curse] == "\n"  ? '' : @array[curse]
  end

  def x(curse = @curse)
    @position[curse][1] < 0 ? @position[curse - 1][1] + 1 : @position[curse][1]
  end

  def y(curse = @curse)
    @position[curse][1] < 0 ? @position[curse - 1][0] : @position[curse][0]
  end

  def addlt(letter)
    @array.insert(@curse, letter)
    getposition(@curse)
    @curse += 1
  end

  def dellt
    return if @array.size == 1
    @array.delete_at(@curse)
    @curse %= @array.size
    getposition(@curse)
  end

  def move(direct)
    valhash = { l: (@curse - 1) % @array.size, r: (@curse + 1) % @array.size,
                e: @array.size - 1, h: 0 }
    case direct
    when :u then getupline
    when :d then getdownline
    else @curse = valhash[direct]
    end
  end

  private

  def getdownline
    (line, cols) = @position[@curse]
    maxline = @position.transpose[0].max
    @curse = line == maxline ? @curse : getcurse(line + 1, cols)
  end

  def getupline
    (line, cols) = @position[@curse]
    @curse = line == 0 ? @curse : getcurse(line - 1, cols)
  end

  def getcurse(line, cols)
    @position.index([line, cols]) || getcurse(line, cols < 0 ? 0 : cols - 1)
  end

  def getposition(bgn)
    @position.pop(@position.size - bgn)
    @array[bgn..-1].reduce(@position) { |a, e| a << nextpos(a, e) }
  end

  def nextpos(pos, letter)
    return [0, 0] if pos.empty?
    addpos = ->(la) { la[1] == @maxcols ? [la[0] + 1, 0] : [la[0], la[1] + 1] }
    letter == "\n" ? [pos.last[0] + 1, -1] : addpos.call(pos.last)
  end
end

# The basic methods for insert mode
class InsmodeBase
  attr_reader :file
  attr_writer :complist

  public

  def initialize(string, position, winsize, mode, frame)
    @file, @mode, @winsize = TxtFile.new(string, winsize[1] - 1), mode, winsize
    @lsft, @csft = [*position] << 0

    @window = Framewin.new(@winsize[0], @winsize[1], @lsft, @csft, frame)
    @window.cont.keypad(true)

    @quitkey, @chgst, @complist = 10, 9, false
    @chgline = mode == :ml ? 10 : -1
  end

  def reset(string = '')
    @file = TxtFile.new(string, @winsize[1] - 1)
  end

  private

  MVHASH = { KEY_LEFT => :l, KEY_RIGHT => :r, KEY_UP => :u, KEY_DOWN => :d,
             KEY_HOME => :h, KEY_END => :e }
  KEY_DELETE = 263

  def prefixdeal
    showstr(0) && showch
    @tabfocus = false
  end

  def normchar?(char)
    char.is_a?(String) && !@tabfocus
  end

  def delch
    @file.move(:l)
    @file.dellt
    winrefresh
  end

  def winrefresh
    @window.cont.clear
    showstr(0)
  end

  def addch(ch)
    @file.addlt(ch)
    ch == "\n" ? winrefresh : showstr(@file.curse - 1)
  end

  def move(direct)
    @file.move(direct)
    showch
    @window.cont.refresh
  end

  def showch(letter = @file.letter, x = @file.x, y = @file.y)
    @window.cont.setpos(y, x)
    return if (letter == :end) || (letter == '')
    @window.cont.addch(letter)
    @window.cont.setpos(y, x)
  end

  def showstr(bgn = @file.curse)
    @file.each(bgn) { |letter, x, y| showch(letter, x, y) }
    @window.refresh([@file.y, @file.x - 1])
    @window.cont.setpos(@file.y, @file.x)
  end
end

# The insert mode
class Insmode < InsmodeBase
  public

  def initialize(string, position, winsize, mode = :ml, frame = false)
    super(string, position, winsize, mode, frame)
  end

  def deal
    prefixdeal

    contrl = ->(ch) { block_given? ? control(ch) { yield } : control(ch) }
    loop do
      curs_set(1)
      ch = @window.cont.getch
      break if :quit == (normchar?(ch) ? addch(ch) : contrl.call(ch))
    end
    curs_set(0)

    yield if block_given?
  end

  private

  def complete
    @tabfocus = false
    menulist, tocmp = compmenu
    return if menulist.nil? || menulist.empty?
    lsft = @mode == :ml ? @lsft + 1 : @lsft + 2
    word = Menu.new(menulist, [lsft, @csft + @file.x], 10, nil,
                    ['|', '-']).get.sub(tocmp, '')

    word.each_char { |l| @file.addlt(l) }
    yield if block_given?
    winrefresh
  end

  def compmenu
    case @complist
    when :file then obtfilelist
    when false then autocomp
    else [compsele(@complist, @file.string), @file.string]
    end
  end

  def autocomp
    tmplist = @file.string.split(' ')
    [compsele(tmplist[0..-2], tmplist[-1]), tmplist[-1]]
  end

  def obtfilelist
    return unless %r((?<base>.+/)?(?<tocmp>[^/]{0,})) =~ './' + @file.string
    return unless File.directory?(base)
    distgs = ->(x) { File.file?("./#{base}#{x}") ? x : x + '/' }
    [compsele(Dir.foreach(base).to_a, tocmp).map { |x| distgs.call(x) }, tocmp]
  end

  def compsele(list, str)
    list.uniq.select { |item| item.start_with?(str) }
  end

  def control(ch)
    focus = ->(char) { block_given? ? focused(char) { yield } : focused(char) }
    @tabfocus ? focus.call(ch) : unfocused(ch)
  end

  def unfocused(ch)
    case true
    when !MVHASH[ch].nil? then move(MVHASH[ch])
    when ch == KEY_DELETE then delch
    when ch == @chgline then addch("\n")
    when ch == @chgst then @tabfocus = true
    end
  end

  def focused(ch)
    case true
    when ch == @quitkey then :quit
    else block_given? ? complete { yield } : complete
    end
  end
end

# The notes with position information
class Note
  attr_reader :notes, :items, :ptr, :changed

  public

  def initialize(notes, maxh, maxw)
    @notes, @maxh, @maxw, @changed = notes, maxh, maxw, false
    @items = notes.split("\n\n").map { |item| dealitem(item) }
    pagediv(0, :focus)
  end

  def item(order)
    @items[order].map { |line| line.join(' ') }.join("\n")
  end

  def mod(item, order)
    @changed = true
    @items[order] = dealitem(item)
    pagediv(order)
  end

  def swap(uord)
    @changed = true
    @items.swapud!(@ptr.pst, uord)
    pagediv(@ptr.pst)
  end

  def apend(item)
    @changed = true
    @items << dealitem(item)
    @ptr.add(@items.last.flatten.size + 2)
  end

  def ins(item, order)
    @changed = true
    apend(item)
    return if order < 0
    @items[order..-1] = @items[order..-1].rotate!(-1)
    pagediv(order)
  end

  def delete(order = @ptr.pst)
    @changed = true
    @items.delete_at(order)
    pagediv(order > 0 ? order -  1 : order, :focus)
  end

  def store
    @changed = false
    @notes = (0..@items.size - 1)
      .reduce([]) { |a, e| a << item(e) }.join("\n\n")
  end

  private

  def cutline(line, width)
    chgl =
      ->(arr, wd, wid) { arr.empty? ? true : arr[-1].size + wd.size >= wid }
    line.split(' ').reduce([]) do |a, e|
      chgl.call(a, e, width) ? a << e : a[-1] << " #{e}"
      a
    end
  end

  def dealitem(item)
    item.sub(/\A/, '@@').split("\n").select { |ln| ln != '' }
      .map { |ln| cutline(ln, @maxw).map { |l| l.sub('@@', '  ') } }
  end

  def pagediv(curse = 0, stat = @ptr.state)
    @ptr = Pointer.new(@items.reduce([]) { |a, e| a << e.flatten.size + 2 },
                       @maxh, curse, stat)
  end
end

# The basic normal mode
module NormodeBase
  public

  def asks(affairs)
    'y' == showmessage(ASKSTC[affairs]).getch
  end

  private

  ASKSTC = { quit: 'The note has not been saved yet, do you want to quit?',
             store: 'Do you want to store this notes?',
             delete: 'Do you want to delete this item?',
             tag: 'Do you want to tag this item to a key?',
             utag: 'Do you want to remove one of the it\'s tag(s)?',
             add: 'Do you want to add an item?',
             update: 'Do you want to update the bib?'
  }

  INDCSTC = { fileadr: 'Input the file of the item',
              bibadr: 'Input the bibfile of the item',
              bibask: 'Input the bibfile'
  }

  def showmessage(msg)
    win = Window.new(1, @scsize[1], @scsize[0] - 1, 0)
    win.attrset(A_BOLD)
    win.addstr(msg)
    win.refresh
    win
  end
end

# The normal mode
class NoteItfBase
  include NormodeBase
  attr_reader :note, :height

  public

  def initialize(notes, height, scsize, labwid, bdspc)
    @height, @scsize, @labwid, @bdspc = height, scsize, labwid, bdspc
    @contwid = labwid - 2 - 2 * bdspc

    @note = Note.new(notes, scsize[0] - @height - 1, @contwid)

    @frmleft = (scsize[1] - labwid) / 2
    @conleft = @frmleft + @bdspc
  end

  def insert(order = -1)
    curs_set(1)

    ins = Insmode.new('', @height, [@scsize[0] - @height - 1, @scsize[1]])
    ins.deal
    @note.ins(ins.file.string, order)

    curs_set(0)
    pagerefresh
  end

  def mod(order)
    curs_set(1)

    ins = Insmode.new(@note.item(order), @height,
                      [@scsize[0] - @height - 1, @scsize[1]])
    ins.deal
    @note.mod(ins.file.string, order)

    curs_set(0)
    pagerefresh
  end

  def pagerefresh
    clearpage
    @note.ptr.page(@note.ptr.pst) { |ind| show_note(ind) }
    showcurrent
  end

  def showcurrent
    show_note(@note.ptr.pst, @note.ptr.state)
  end

  def picknote
    @note.ptr.chgstat
    showcurrent
  end

  def move(uord)
    @note.swap(uord) if @note.ptr.state == :picked
    showmessage(@note.ptr.state.to_s)
    show_note
    uord == :u ? @note.ptr.down && pagerefresh : @note.ptr.up && pagerefresh
    showcurrent
  end

  def store
    @note.store if asks(:store)
  end

  def delete
    @note.delete && pagerefresh if asks(:delete)
  end

  private

  QUITSTC = 'The note has not been saved yet, do you want to quit?'

  def clearpage
    win = Window.new(@scsize[1], @scsize[0], @height, 0)
    win.refresh
    win.close
  end

  def show_note(order = @note.ptr.pst, state = false)
    return if @note.items.empty?
    hegt, alti = @note.ptr.len[order], @note.ptr.location[order] + @height

    frame = state == :picked ? %w(! ~) : %w(| -)
    content = Framewin.new(hegt - 2 , @contwid + 1, alti, @conleft, frame)
    content.framewin.attrset(A_BOLD) if state
    content.framewin.attron(color_pair(6))

    content.cont.addstr(@note.items[order].join("\n"))
    content.refresh
  end
end

# The interface of note
class NoteItf < NoteItfBase
  public

  def initialize(notes, head, scsize, labwid, bdspc)
    super(notes, showhead(head), scsize, labwid, bdspc)
  end

  def deal
    pagerefresh

    loop do
      char = showmessage('').getch
      store if char == 's'
      normdeal(char) || insdeal(char)
      break if char == 'q' && (@note.changed ? asks(:quit) : true)
    end
  end

  private

  HEAD_KEYS = %W(Titile Author identifier)

  def addstring(string, pair = -1, bold = false)
    attrset(A_BOLD) if bold
    attron(color_pair(pair))

    addstr(string)

    attroff(A_BOLD) if bold
    attroff(color_pair(pair))
  end

  def showline(key, content)
    addstring("#{key}: ", 2, true)
    addstring("#{content}\n", 0)
  end

  def showhead(head)
    head[1] = Author.short(head[1])
    setpos(0, 0)
    (0..2).each { |ind| showline(HEAD_KEYS[ind], head[ind]) }
    addstring('^' * cols, 6, true)
    refresh

    headstr = "Title: #{head[0]}\nAuthor: #{head[1]}\nidentifier: #{head[2]}\n"
    Note.new(headstr, lines, cols).items.flatten.size + 1
  end

  def insdeal(char)
    return if @note.items.empty? && char == 'm'
    case char
    when 'a' then insert
    when 'i' then insert(@note.ptr.pst)
    when 'm' then mod(@note.ptr.pst)
    end
  end

  def normdeal(char)
    return if @note.items.empty?
    case char
    when 'd' then delete
    when 'p' then picknote
    when 'j' then move(:d)
    when 'k' then move(:u)
    end
  end
end

# The utils for cmdbib
CmdBibBase = Struct.new(:bib) do

  private

  def search_idents(word)
    return [] if word == ''
    bib.get_slist(word.split(' '))
      .map { |item| [item[0], bib.getkeynames(item[1]), item[5]] }.transpose
  end

  def listidents(idents)
    table = bib.db.selects(:bibref, %w(identifier id title),
                           idents.map { 'identifier' }, idents)
      .map { |item| [item[0], bib.getkeynames(item[1]), item[2]] }
    idents.map { |x| table.find { |term| term[0] == x } }
      .select { |x| x }.transpose
  end

  def obtainlist(list, flag)
    list.map { |x| bib.db.select(:bibref, %w(identifier id title), flag, x) }
      .map { |item, _| [item[0], bib.getkeynames(item[1]), item[2]] }.transpose
  end

  def keyidents(keyname)
    obtainlist(bib.lskey(keyname), :id)
  end

  def listrefresh
    newlist = obtainlist(@list.to_a, :identifier)
    @list.set(@list.curse, @list.scurse, newlist)
  end

  def gcont(ident)
    return [] if ident == ''
    a = bib.db.select(:bibref, %w(title author id journal volume pages note),
                      :identifier, ident).flatten

    return [] unless a[3..5]
    [a[0], Author.short(a[1].to_s), bib.getkeynames(a[2]),
     a[3..5].join(' '), a[6]]
  end

  def gkeys
    scr = %W(All References Tagged Query Online Import Cited Trash) << ''
    bib.db.select(:bibrefkey, :key_name, :user, bib.username).flatten - scr
  end

  def refreshpanel(listref = false)
    listrefresh if listref
    clear
    refresh
    showc
    @list.mrefresh
  end

  def update
    return showmessage('') unless asks(:update)

    showmessage(NormodeBase::INDCSTC[:bibask])
    bibname = listdiag(:file, NormodeBase::INDCSTC[:bibask])
    return showmessage('') if bibname == ''

    bibname = File.expand_path(bibname)
    bib.modbib(bibname, @list.current)
    FileUtils.mv(bibname, TMPFILE) unless bibname == TMPFILE
    showmessage('')
  end

  TMPFILE = File.expand_path('~/Documents/tmp.bib')
  def add
    return showmessage('') unless asks(:add)

    showmessage(NormodeBase::INDCSTC[:fileadr])
    filename = listdiag(:file, NormodeBase::INDCSTC[:fileadr])

    showmessage(NormodeBase::INDCSTC[:bibadr])
    bibname = listdiag(:file, NormodeBase::INDCSTC[:bibadr])

    return showmessage('') if filename == '' || bibname == ''
    bib.addbib(filename, bibname)
    FileUtils.mv(bibname, TMPFILE) if bibname != TMPFILE
    showmessage('')
  end

  def tagged
    listdiag(gkeys) { |key| bib.link_item(key, @list.current) } if asks(:tag)
    showmessage('')
  end

  def rmtag
    keys, bibkey = @list.current(1).gsub(' ', '').split(','), @list.current
    listdiag(keys) { |key| bib.unlink_item(key, bibkey) } if asks(:utag)
    showmessage('')
  end

  def delete
    bib.debib_action(@list.current, "y\n") if asks(:delete)
    showmessage('')
  end

  def cstat
    @stat = @stat == :content ? :list : :content
    visible = @stat == :content ? [7, false, false] : [7, 5, true]
    @list.setcol(visible)
  end

  def noting
    return if @list.current == ''
    clear
    ((author, title, notes)) = bib.db
      .select(:bibref, %w(author title note), :identifier, @list.current)

    head = [title, author, @list.current]
    pad = NoteItf.new(notes, head, @scsize, @scsize[1], 1)
    pad.deal
    bib.storenote(@list.current, pad.note.notes)
    refreshpanel
  end
end

# The main class for cmdbib
class CmdBib < CmdBibBase
  include  NormodeBase
  attr_reader :list

  public

  def initialize(height, width, db)
    super(db)
    @scsize = [height, width]
    @stat, lsl, lsw, keyw = :content, height - 3, width / 8, width / 9
    inipanel(lsl, width, lsw, keyw)

    @diag = Insmode.new('', [@scsize[0] / 3, @scsize[1] * 0.05],
                        [1, @scsize[1] * 0.9], :cmd, ['|', '-'])
    @contwin.refresh
  end

  def deal
    @list.get { |cont, char| control(char) }
  end

  private

  def inipanel(lsl, width, lsw, keyw)
    keysft, titsft, titw = lsw + 1, lsw + keyw + 2, width - lsw - keyw - 5

    @list = AdvMenu.new([[], [], []], [0, 0, keysft, titsft], [lsl, true],
                        titw, ['|', '-'])
    @list.setctrl(['q'], ['j', KEY_DOWN, 9, 10, ' '], ['k', KEY_UP])
    @list.setcol([7, false, false])

    @contwin = Framewin.new(lsl, width - lsw - 4, 0, lsw + 2, ['|', '-'])
  end

  def showc
    showcont(gcont(@list.current)) if @stat == :content
    true
  end

  SPLITCHAR = ["\n", ' ', "\n\n"]
  COLORS = [2, 5, 6]
  def showcont(content)
    @contwin.cont.clear
    @contwin.refresh
    return if content.empty?

    @contwin.cont.setpos(0, 0)
    @contwin.cont.addstr(content.shift + "\n")
    @contwin.cont.attrset(A_BOLD)
    (0..2).each { |i| contadd(content.shift + SPLITCHAR[i], COLORS[i]) }
    @contwin.cont.attroff(A_BOLD)
    contadd(BaseBibUtils.fmtnote(content.shift), 8)

    @contwin.cont.refresh
  end

  def contadd(string, color)
    @contwin.cont.attron(color_pair(color))
    @contwin.cont.addstr(string)
  end

  def control(char)
    case char
    when /[dautr]/ then bibdeal(char)
    when /[sl]/ then diagdeal(char)
    when /[Rcohn]/ then normctrl(char)
    end
    showc
  end

  def normctrl(char)
    case char
    when 'R' then refreshpanel(true)
    when 'c' then cstat
    when 'n' then noting
    when 'h' then listhistory
    when 'o' then @list.current != '' && bib.opbib_core(@list.current)
    end
  end

  def diagdeal(char)
    case char
    when 's' then listdiag { |word| @list.set(0, 0, search_idents(word)) }
    when 'l' then listdiag(gkeys) { |key| @list.set(0, 0, keyidents(key)) }
    end
  end

  def bibdeal(char)
    case char
    when 'd' then delete
    when 'a' then add
    when 'u' then update
    when 't' then tagged
    when 'r' then rmtag
    end
  end

  def listhistory
    identlist = File.new(File.expand_path('~/.opbib_history')).each
      .map { |line| line.split(' ')[-1] }.reverse.uniq[0..29]
    @list.set(0, 0, listidents(identlist))
  end

  def listdiag(comps = false, bgstrs = '')
    @diag.reset
    @diag.complist = comps
    @diag.deal { refreshpanel; showmessage(bgstrs) }

    yed = ->(str) { str == '' ? str : yield(str) }
    block_given? ? yed.call(@diag.file.string) : @diag.file.string
  end
end

def colorinit
  init_pair(1, COLOR_RED, -1)
  init_pair(2, COLOR_GREEN, -1)
  init_pair(3, COLOR_YELLOW, -1)
  init_pair(4, COLOR_BLUE, -1)
  init_pair(5, COLOR_MAGENTA, -1)
  init_pair(6, COLOR_CYAN, -1)
  init_pair(7, COLOR_WHITE, -1)
  init_pair(8, -1, -1)
end
