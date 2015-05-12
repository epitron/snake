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

  def ==(other); x == other.x and y == other.y; end
  def eql?(other); self == other; end
  def hash; [x, y].hash; end
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
    @chomp_count += 1
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
  end

  def ate_itself?
    body.index(head)
  end

  def alive?
    not ate_itself?
  end

end


class Food < Struct.new(:icon, :color)
  FOOD_ICONS = {
    "🍄"=>"white",
    "🍅"=>"red",
    "🍆"=>"violet",
    "🍇"=>"purple",
    "🍈"=>"yellow",
    "🍉"=>"red",
    "🍊"=>"orange",
    "🍋"=>"yellow",
    "🍌"=>"yellow",
    "🍍"=>"yellow",
    "🍎"=>"light red",
    "🍰"=>"tan",
    "🍐"=>"lime green",
    "🍑"=>"orange",
    "🍒"=>"red",
    "🍓"=>"hot pink",
    "🍔"=>"yellow",
    "🍕"=>"orange",
    "🍖"=>"cyan",
    "🍗"=>"brown",
    "🍘"=>"white",
    "🍙"=>"white",
    "🍚"=>"white",
    "🍛"=>"red",
    "🍜"=>"white",
    "🍞"=>"yellow",
    "🍩"=>"pink",
    "🍪"=>"rosy brown",
    "🍫"=>"brown",
    "🍟"=>"yellow",
    "🍡"=>"light salmon",
    "🍢"=>"khaki",
    "🍣"=>"lemon chiffon",
    "🍤"=>"sea shell",
    "🍭"=>"light cyan"
  }
# 🍩 pink 🍪 beige 🍫 brown 🍟 yellow 🍡 light salmon 🍢 khaki 🍣 🍤 sea shell 🍭 light cyan
#  🍠 🍥 🍦 🍧 🍨  🍬 🍭 🍮 🍯

  FOODS = FOOD_ICONS.map do |icon, color|
    Food.new(icon, color.to_s)
  end

  def self.random
    FOODS.sample
  end
end


# class Food < Pos

#   attr_reader :icon
  
#   # ICONS = %w[✼ ✾ ✿ ❀ ❁ ❂ ❃]
#   ICONS = %w[
#     🍄 🍅 🍆 🍇 🍈 🍉 🍊 🍋 🍌 🍍 🍎 🍏 🍰
#     🍐 🍑 🍒 🍓 🍔 🍕 🍖 🍗 🍘 🍙 🍚 🍛 🍜 🍝 🍞 🍟
#     🍠 🍡 🍢 🍣 🍤 🍥 🍦 🍧 🍨 🍩 🍪 🍫 🍬 🍭 🍮 🍯
#   ]  

#   def initialize(x, y)
#     super(x, y)
#     @icon = ICONS.sample
#   end

# end


class Board

  attr_reader :size, :snake, :foods

  def initialize(amount_of_food=20, width=40, height=20)
    @size           = Pos.new(width, height)
    @amount_of_food = amount_of_food

    reset!
  end

  def random_pos
    Pos.new rand(size.x), rand(size.y)
  end

  def reset!
    @snake = Snake.new(self, :up)
    @dead_counter = nil

    @foods = {}

    @amount_of_food.times do
      pos = random_pos
      redo if foods[pos]

      foods[pos] = Food.random
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
    foods.each do |pos, morsel|
      show(morsel.icon, pos, morsel.color)
    end

    snake.body.each.with_index do |pos,i|
      if snake.alive?
        color = rainbow(i)
      else
        color = :red
      end

      # ◍ ◎
      show('◉', pos, color)
    end

    # show("👾", snake.head, :bright, :green)
    if snake.alive?
      show(snake.head_icon, snake.head, :bright, :green)
    else
      show(snake.head_icon, snake.head, :bright, :red)
    end
  end

  def update
    if snake.ate_itself?
      @dead_counter ||= 10
      @dead_counter -= 1
      if @dead_counter < 0
        reset!
      end
    else
      snake.move!

      if foods[snake.head]
        foods.delete(snake.head)
        snake.grow!
      end
    end
  end

end

board = Board.new(50)

keymap = KeyMap.new do
  key(:up)      { board.snake.up!    }
  key(:down)    { board.snake.down!  }
  key(:left)    { board.snake.left!  }
  key(:right)   { board.snake.right! }
  key("g")   { board.snake.grow!(20) }
  key("n")   { board.reset! }

  key("q", "Q", "\C-c") { KeyMap.quit! }
end

Thread.new do
  begin
    loop do
      clear
      board.draw
      sleep 0.13
      board.update
    end
  rescue => e
   p e
   exit 1
 end
end


hide_cursor
IO.console.raw { |io| keymap.process(io) }
show_cursor
clear
