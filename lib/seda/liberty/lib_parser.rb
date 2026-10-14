require "strscan"


module Liberty
  Token = Struct.new(:kind, :data, :num_line)

  class Lexer
    WORDS = %w[library cell pin timing cell_rise cell_fall index_1 index_2 values]
    SIGNS = {
      "(" => :lpar, ")" => :rpar, "{" => :lbrace, "}" => :rbrace,
      ":" => :colon, ";" => :semicolon, "," => :comma
    }

    def lexify(path)
      source = StringScanner.new(File.read(path))
      tokens = []
      line = 1

      until source.eos?
        if (text = source.scan(/\s+/m)) # skip whitespace
          line += text.count("\n")
        elsif (text = source.scan(%r{/\*.*?\*/}m))  # skip comments
          line += text.count("\n")
        elsif source.scan(%r{//[^\n]*})# skip single-line comments
          next
        elsif (text = source.scan(/\\[ \t]*\r?\n/))
          line += text.count("\n")
        elsif (text = source.scan(/"(?:\\.|[^"])*"/m))# match chaine of characters between double quotes
          tokens << Token.new(:string, text[1...-1], line)
          line += text.count("\n")
        elsif (text = source.scan(/[(){}:;,]/)) # match signs
          tokens << Token.new(SIGNS.fetch(text), text, line)
        elsif (text = source.scan(/[^\s(){}:;,"\\]+/)) # match words
          kind = WORDS.include?(text) ? text.to_sym : :word #
          tokens << Token.new(kind, text, line)
        else
          raise "ERROR at #{line}: #{source.getch.inspect}"
        end
      end
      tokens
    end
  end

  class Parser
    def parse(path, cell_name:, input_slew:, output_load:)
      @tokens = Lexer.new.lexify(path)
      @cell_name = cell_name
      @input_slew = input_slew
      @output_load = output_load

      result = parse_library
      raise "Cellule introuvable : #{cell_name}" unless result
      result
    end

    def acceptIt
      @tokens.shift
    end

    def showNext
      lookAhead(1)
    end

    def lookAhead(n)
      @tokens[n - 1]
    end

    def expect(kind)
      token = showNext
      raise "ERROR: end of file" unless token
      if token.kind != kind
        raise "ERROR at #{token.num_line}: expected #{kind}, got #{token.kind}"
      end
      acceptIt
    end

    private

    def parse_library
      expect :library
      skip_balanced :lpar, :rpar
      expect :lbrace

      until showNext.kind == :rbrace
        if showNext.kind == :cell
          result = parse_cell # on delegate parsing to parse_cell, which will return nil if the cell name does not match
          return result if result
        else
          skip_statement
        end
      end
      expect :rbrace
      nil
    end

    def parse_cell
      expect :cell
      name = parse_argument
      expect :lbrace

      unless name == @cell_name
        skip_block_body
        return nil
      end

      delays = []
      until showNext.kind == :rbrace
        if showNext.kind == :pin
          delays.concat parse_pin
        else
          skip_statement
        end
      end
      expect :rbrace

      rises = delays.map(&:first).compact
      falls = delays.map(&:last).compact
      raise "Aucun délai trouvé dans #{name}" if rises.empty? && falls.empty?
      # in .lib rise and fall are defined based on the output load, so we return the maximum value for each!!
      { cell: name, rise: rises.max, fall: falls.max }
    end

    def parse_pin
      expect :pin
      skip_balanced :lpar, :rpar
      expect :lbrace

      delays = []
      until showNext.kind == :rbrace
        if showNext.kind == :timing
          delay = parse_timing
          delays << delay if delay
        else
          skip_statement
        end
      end
      expect :rbrace
      delays
    end

    def parse_timing
      expect :timing
      skip_balanced :lpar, :rpar
      expect :lbrace
      rise = nil
      fall = nil

      until showNext.kind == :rbrace
        case showNext.kind
        when :cell_rise then rise = parse_table(:cell_rise)
        when :cell_fall then fall = parse_table(:cell_fall)
        else skip_statement
        end
      end
      expect :rbrace
      [rise, fall] if rise || fall
    end

    def parse_table(kind)
      expect kind
      skip_balanced :lpar, :rpar
      expect :lbrace
      slew = []
      load = []
      values = []

      until showNext.kind == :rbrace
        case showNext.kind
        when :index_1 then slew = parse_numbers(:index_1)
        when :index_2 then load = parse_numbers(:index_2)
        when :values then values = parse_numbers(:values)
        else skip_statement
        end
      end
      expect :rbrace
      return if slew.empty? || load.empty? || values.empty?

      row = slew.each_index.min_by { |i| (slew[i] - @input_slew).abs } #on prend l'index de la valeur de slew la plus proche de l'input_slew
      column = load.each_index.min_by { |i| (load[i] - @output_load).abs }
      values.fetch(row * load.length + column)
    end

    def parse_numbers(kind)
      expect kind
      expect :lpar
      numbers = []
      until showNext.kind == :rpar
        token = acceptIt
        numbers.concat(token.data.split(",").map { |x| Float(x) }) if token.kind == :string
      end
      expect :rpar
      expect :semicolon
      numbers
    end

    def parse_argument
      expect :lpar
      value = nil
      until showNext.kind == :rpar
        token = acceptIt
        value ||= token.data if [:word, :string].include?(token.kind)
      end
      expect :rpar
      value
    end

    def skip_statement
      token = acceptIt
      case showNext&.kind
      when :colon
        acceptIt
        acceptIt until showNext.kind == :semicolon
        expect :semicolon
      when :lpar
        skip_balanced :lpar, :rpar
        skip_balanced(:lbrace, :rbrace) if showNext&.kind == :lbrace
        expect(:semicolon) if showNext&.kind == :semicolon
      when :lbrace
        skip_balanced :lbrace, :rbrace
      when :semicolon
        expect :semicolon
      else
        raise "ERROR at #{token.num_line}: cannot skip #{token.data}"
      end
    end

    def skip_balanced(opening, closing)
      expect opening
      depth = 1
      until depth.zero?
        token = acceptIt
        raise "Bloc Liberty non fermé" unless token
        depth += 1 if token.kind == opening
        depth -= 1 if token.kind == closing
      end
    end

    def skip_block_body
      depth = 1
      until depth.zero?
        token = acceptIt
        raise "Bloc Liberty non fermé" unless token
        depth += 1 if token.kind == :lbrace
        depth -= 1 if token.kind == :rbrace
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  abort "Usage: ruby #{__FILE__} fichier.lib cellule slew_ns charge_pF" unless ARGV.size == 4
  file, cell, slew, load = ARGV
  result = Liberty::Parser.new.parse(
    file, cell_name: cell, input_slew: Float(slew), output_load: Float(load)
  )
  puts "#{result[:cell]} | rise=#{result[:rise]} ns | fall=#{result[:fall]} ns"
end
