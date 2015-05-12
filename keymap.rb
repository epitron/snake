#######################################################################################################
# A little DSL for defining keyboard commands

class KeyMap

  class Quit < Exception; end

  attr_accessor :config

  def initialize(&block)
    @config = Config.new(&block)
  end

  def self.quit!; raise Quit; end
  def quit!;      raise Quit; end

  def process(input)
    level = config.trie_root

    # Read one character at a time from the input, and incrementally
    # walk through levels of the trie until a :handler is found, or
    # we hit a dead-end in the trie.
    loop do
      c = input.getc

      handler = nil

      if found = level[c]
        level = found

        if handler = level[:handler]
          level = config.trie_root
        end
      else
        handler = config.default
        level   = config.trie_root
      end

      handler.call(c) if handler
      config.always.call(c) if config.always
    end

  rescue Quit
    # one of the key handlers threw a KeyMap::Quit
  end



  class Config

    NAMED_KEYS = {
      :up     => "\e[A",
      :down   => "\e[B",
      :right  => "\e[C",
      :left   => "\e[D",
      :home   => ["\eOH", "\e[1~"],
      :end    => ["\eOF", "\e[4~"],
      :pgup   => "\e[5~",
      :pgdown => "\e[6~",
      :ctrl_c => "\C-c"
    }

    attr_accessor :trie_root

    def initialize(&block)
      @trie_root = {}

      # Make sure ^C is defined
      key(:ctrl_c) { raise KeyMap::Quit }

      instance_eval(&block)
    end

    #
    # Add a command to the trie of input sequences
    #
    def key(*seqs, &block)
      seqs = seqs.flat_map { |seq| NAMED_KEYS[seq] || seq }

      seqs.each do |seq|
        level = @trie_root

        seq.each_char do |c|
          level = (level[c] ||= {})
        end
        
        level[:handler] = block
      end
    end

    #
    # This block will be run if the key isn't defined.
    #
    def default(&block)
      if block_given? then @default = block else @default end
    end

    def always(&block)
      if block_given? then @always = block else @always end
    end

  end

end
