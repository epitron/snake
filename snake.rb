require 'io/console'
require 'paint'
require_relative 'keymap'

##################################################################################
# http://en.wikipedia.org/wiki/Emoji#In_the_Unicode_standard
#
# TODOs:
# - high performance rendering (only render differences)
# - non-threaded event loop
# - buffer up movement commands
#

def clear
  print "\e[H\e[2J"
end

def home
  print "\e[1;1H"
end

def move_to(pos)
  print "\e[#{pos.y+1};#{pos.x+1}H"
end

def show(str, pos, *colors)
  move_to(Pos.new(pos.x*2, pos.y))
  print Paint[str, *colors]
end

def hide_cursor
  print "\e[?25l"
end

def show_cursor
  print "\e[?25h"
end

def rainbow(i)
  freq   = 0.5
  # spread = 3.0
  # i      = i / spread
  red    = Math.sin(freq*i + 0) * 127 + 128
  green  = Math.sin(freq*i + 2*Math::PI/3) * 127 + 128
  blue   = Math.sin(freq*i + 4*Math::PI/3) * 127 + 128
  "#%02X%02X%02X" % [ red, green, blue ]
end

##################################################################################

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

##################################################################################

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
      if body.empty? or (head + DIRECTION_VECTOR[dir]) != body.first
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

##################################################################################

class Food < Struct.new(:icon, :color)
  FOOD_ICONS = {
    "🍄"=>"white",
    "🍅"=>"orange red",
    "🍆"=>"#6600FF",
    "🍇"=>"#944DFF",
    "🍈"=>"yellow",
    "🍉"=>"red",
    "🍊"=>"orange",
    "🍋"=>"yellow",
    "🍌"=>"yellow",
    "🍍"=>"yellow",
    "🍎"=>"red",
    "🍰"=>"#FFFF99",
    "🍐"=>"lime green",
    "🍑"=>"#FFCC99",
    "🍒"=>"red",
    "🍓"=>"hot pink",
    "🍔"=>"#FFCC00",
    "🍕"=>"orange",
    "🍖"=>"cyan",
    "🍗"=>"#FFB870",
    "🍘"=>"white",
    "🍙"=>"white",
    "🍚"=>"white",
    "🍜"=>"white",
    "🍞"=>"sandy brown",
    "🍩"=>"pink",
    "🍪"=>"rosy brown",
    "🍫"=>"brown",
    "🍟"=>"yellow",
    "🍡"=>"light salmon",
    "🍢"=>"khaki",
    "🍣"=>"lemon chiffon",
    "🍤"=>"#FF9966",
    "🍭"=>"magenta",
  }

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

##################################################################################

class Board

  attr_reader :size, :snake, :foods, :level, :lives, :initial_food

  def initialize(initial_food=20, width=20, height=20)
    @size         = Pos.new(width, height)
    @initial_food = initial_food

    restart!
  end

  def reset!
    @snake = Snake.new(self, :up)
    @dead_counter = nil

    grow_food!
  end

  def restart!
    @lives = 3
    @level = 1
    reset!
  end

  def retry!
    reset!
  end

  def next_level!
    @level += 1
    reset!
  end    

  def grow_food!
    @foods = {}
    amount = (initial_food * (1.5**(level-1))).to_i

    amount = size.x * size.y if amount > size.x * size.y

    amount.times do
      pos = random_pos
      redo if foods[pos]
      foods[pos] = Food.random
    end
  end    


  def win!
    200.times do |n|
      snake.body.each.with_index do |pos, i|
        show('◉', pos, rainbow(i+n))
      end

      color = rainbow(n)

      show(snake.head_icon, snake.head, color)

      status_message("========== YOU WIN!!! ============", color)

      sleep 0.01
    end
    next_level!
  end

  def die!
    @dead_counter ||= 10
    @dead_counter -= 1

    if @dead_counter < 0
      if lives > 0
        @lives -= 1
        retry!
      else
        10.times do |n|
          status_message("------------ GAME OVER! ----------------", :bright, [:red, :green][n%2])
          sleep 0.3
        end
        restart!
      end
    end
  end

  def center; size/2; end

  def random_pos
    Pos.new rand(size.x), rand(size.y)
  end

  def status_message(msg, *colors)
    move_to(Pos.new(0,size.y+1))
    print Paint[msg, *colors]
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

      show('◉', pos, color) # ◍ ◎ ◉
    end

    if snake.alive?
      show(snake.head_icon, snake.head, :bright, :green)
    else
      show(snake.head_icon, snake.head, :bright, :red)
    end

    status_message(
      Paint['👾 ' * lives, :cyan] + 
      Paint["  Level #{level}  ", :green] + 
      Paint["(#{foods.size} foods remaining)", :bright, :red]
    )
  end

  def update
    if foods.empty?
      win!
    elsif snake.ate_itself?
      die!
    else
      snake.move!

      if foods[snake.head]
        foods.delete(snake.head)
        snake.grow!(2)
      end
    end
  end


end

##################################################################################

board = Board.new

keymap = KeyMap.new do
  key(:up)      { board.snake.up!    }
  key(:down)    { board.snake.down!  }
  key(:left)    { board.snake.left!  }
  key(:right)   { board.snake.right! }

  key("g")      { board.snake.grow!(20) }
  key("r")      { board.restart! }
  key("w")      { board.win! }

  key("q", "Q", "\C-c") { KeyMap.quit! }
end

##################################################################################

Thread.new do
  begin
    loop do
      clear
      board.draw
      sleep 0.13
      board.update
    end
  rescue => e
   p e, e.backtrace
   exit 1
 end
end

##################################################################################

hide_cursor
IO.console.raw { |io| keymap.process(io) }
show_cursor
clear
