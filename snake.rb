require 'io/console'
require 'paint'
require_relative 'keymap'

# http://en.wikipedia.org/wiki/Emoji#In_the_Unicode_standard

def clear
  print "\e[H\e[2J"
end

def home
  print "\e[1;1H"
end

def move_to(pos)
  print "\e[#{pos.y+1};#{pos.x+1}H"
end

def hide_cursor
  print "\e[?25l"
end

def show_cursor
  print "\e[?25h"
end

def rainbow(i)
  freq   = 1.0
  # spread = 3.0
  # i      = i / spread
  red    = Math.sin(freq*i + 0) * 127 + 128
  green  = Math.sin(freq*i + 2*Math::PI/3) * 127 + 128
  blue   = Math.sin(freq*i + 4*Math::PI/3) * 127 + 128
  "#%02X%02X%02X" % [ red, green, blue ]
end



class Pos
  attr_accessor :x, :y

  def self.[](x,y); new(x,y); end

  def initialize(x, y); @x, @y = x, y; end

  def ==(other); x == other.x and y == other.y; end

  def +(other); Pos.new(x + other.x, y + other.y); end
  def -(other); Pos.new(x + other.x, y + other.y); end
  def /(n);     Pos.new(x / n, y / n); end
  def *(n);     Pos.new(x * n, y * n); end

  def wrap!(board_size)
    @x = @x % board_size.x
    @y = @y % board_size.y

    self
  end

  def inspect
    "<#{x},#{y}>"
  end
end



class Snake < Array

  alias_method :grow,   :unshift
  alias_method :shrink, :pop

  alias_method :head, :first

  def body; self[1..-1]; end

  alias_method :each_segment, :each

  attr_accessor :direction

  def initialize(board, direction)
    @board       = board
    @direction   = direction
    @growth      = 0
    @chomp_count = 0

    # start position
    self << board.center
  end

  DIRECTION_VECTOR = {
    :left  => Pos.new(-1, 0),
    :right => Pos.new( 1, 0),
    :up    => Pos.new( 0,-1),
    :down  => Pos.new( 0, 1),
  }

  OPPOSITE_DIRECTION = {
    :left  => :right,
    :up    => :down,
    :right => :left,
    :down  => :up,
  }

  def direction_vector
    DIRECTION_VECTOR[@direction]
  end

  %i[up down left right].each do |dir|
    define_method("#{dir}!") do
      if body.empty? or dir != OPPOSITE_DIRECTION[direction]
        @direction = dir
      end
    end
  end


  HEADS = {
    :up    => "ᗢᗜ",
    :down  => "ᗣᗝ",
    :left  => "ᗤᗞ",
    :right => "ᗧᗡ"
  }

  def head_icon
    heads = HEADS[direction]
    heads[@chomp_count % heads.size]
  end

  def grow!(n=1)
    @growth += n
  end

  def move!
    next_point = head + direction_vector
    next_point.wrap!(@board.size)

    grow next_point

    if @growth > 0
      @growth -= 1
    else
      shrink
    end

    @chomp_count += 1
  end

end

class Food < Pos

  attr_reader :icon
  
  # ICONS = %w[✼ ✾ ✿ ❀ ❁ ❂ ❃]
  ICONS = %w[
    🍄 🍅 🍆 🍇 🍈 🍉 🍊 🍋 🍌 🍍 🍎 🍏 🍰
    🍐 🍑 🍒 🍓 🍔 🍕 🍖 🍗 🍘 🍙 🍚 🍛 🍜 🍝 🍞 🍟
    🍠 🍡 🍢 🍣 🍤 🍥 🍦 🍧 🍨 🍩 🍪 🍫 🍬 🍭 🍮 🍯
  ]  

  def initialize(board)
    super rand(board.size.x), rand(board.size.y)
    @icon = ICONS.sample
  end

end


class Board

  attr_reader :size, :snake, :food

  def initialize(starting_food=20, width=40, height=20)
    @size          = Pos.new(width, height)
    @starting_food = starting_food

    reset!
  end

  def reset!
    @snake = Snake.new(self, :up)
    @food  = []

    add_food(@starting_food)
  end    

  def add_food(n)
    n.times do 
      morsel = Food.new(self)
      redo if snake.include?(morsel)
      @food << morsel
    end
  end

  def center
    @size/2
  end

  def show(str, pos, *colors)
    move_to(pos)
    print Paint[str, *colors]
  end

  def draw
    food.each do |morsel|
      show(morsel.icon, morsel)
    end

    snake.body.each.with_index do |pos,i|
      show('◉', pos, rainbow(i))
      # show('◉', pos, :bright, :yellow)
    end

    # show("👾", snake.head, :bright, :green)
    show(snake.head_icon, snake.head, :bright, :green)
  end

  def update
    snake.move!

    if snake.body.index(snake.head)
      reset!
    end

    if morsel_position = food.index(snake.head)
      food.delete_at(morsel_position)
      snake.grow!
    end
  end

end

board = Board.new(50)

keymap = KeyMap.new do
  key(:up)      { board.snake.up!    }
  key(:down)    { board.snake.down!  }
  key(:left)    { board.snake.left!  }
  key(:right)   { board.snake.right! }

  key("q", "Q", "\C-c") { KeyMap.quit! }
end

Thread.new do
  loop do
    clear
    board.draw
    sleep 0.17
    board.update
  end
end

hide_cursor
IO.console.raw { |io| keymap.process(io) }
show_cursor
clear
